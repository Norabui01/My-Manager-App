import 'package:flutter/material.dart';
import 'package:at_onboarding_flutter/at_onboarding_flutter.dart';
import 'package:at_utils/at_logger.dart';
import 'dart:async';
import 'dart:convert';
import 'onboarding_configuration.dart';
import 'data_models.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

//import 'global_listener.dart';
// Chat Detail Screen - Individual chat conversation
class ChatDetailScreen extends StatefulWidget {
  final ChatConversation conversation;
  final String currentAtSign;
  final Function(ChatMessage) onMessageSent;

  const ChatDetailScreen({
    super.key,
    required this.conversation,
    required this.currentAtSign,
    required this.onMessageSent,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  AtClientManager? atClientManager;

  final AtSignLogger _logger = AtSignLogger('ChatDetailScreen');
  final Set<String> _handledNotificationKeys = {};
  StreamSubscription<AtNotification>? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    atClientManager = AtClientManager.getInstance();
    _setupNotificationListener();
    _scrollToBottom();
  }

  Future<void> _reloadMessages() async {
  try {
    final keys = await MessageSyncHelper.getMessageKeys(
      atClientManager!.atClient,
      widget.conversation.otherAtSign,
      widget.currentAtSign,
    );

    List<ChatMessage> loadedMessages = [];
    Set<String> seenIds = {};

    for (final key in keys) {
      if (seenIds.contains(key.toString())) continue;
      final atValue = await atClientManager!.atClient.get(key);
      if (atValue.value != null) {
        final data = jsonDecode(atValue.value!);
        loadedMessages.add(ChatMessage(
          id: key.toString(),
          text: data['text'] ?? '',
          isMe: key.sharedBy == widget.currentAtSign,
          timestamp: DateTime.parse(data['timestamp'] ?? DateTime.now().toIso8601String()),
          senderAtSign: key.sharedBy ?? '',
        ));
        seenIds.add(key.toString()); 
      }
    }

    loadedMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    if (mounted) {
      setState(() {
        widget.conversation.messages = loadedMessages;
      });
      _scrollToBottom();
    }
  } catch (e) {
    _logger.severe('Error reloading messages: $e');
  }
}

  Future<void> _setupNotificationListener() async {
    //if (isNotificationListenerSet) return;
    //isNotificationListenerSet = true;
    try {
      final notificationService = atClientManager?.atClient.notificationService;

      if (notificationService != null) {
        _notificationSubscription = notificationService.subscribe(regex: '.*', shouldDecrypt: true).listen((incomingNotification) {

        final key = incomingNotification.key.toLowerCase();

        
        final from = incomingNotification.from;
        final value = incomingNotification.value ?? '';
        final uniqueKey = '$key|$from|$value';

        //set of string to remember the subcribed keys
        if (_handledNotificationKeys.contains(uniqueKey)) {
          _logger.info('Duplicate notification ignored: $uniqueKey');
          return;//if duplicate key, skip
        }
        _handledNotificationKeys.add(uniqueKey);
          _logger.info('Notification received in detail: $uniqueKey from ${incomingNotification.from}');
          _handleIncomingMessage(incomingNotification);
        }, onError: (e) {
          _logger.severe('Notification error in detail: $e');
        });

        _logger.info('Detail screen notification listener setup complete');
      }
    } catch (e) {
      _logger.severe('Error setting up notification listener in chat detail: $e');
    }
  }

  void _handleIncomingMessage(AtNotification notification) {
    //skip system sync
    if (notification.key.contains('statsNotification')) return;
    // Only process messages from the conversation partner
    if (notification.from == widget.conversation.otherAtSign &&
        (notification.key.contains('message.') || notification.key.contains('notify.message.'))) {
           _reloadMessages();  // reload all messages when a new message notification arrives
      try {
        final messageData = jsonDecode(notification.value ?? '{}');

        // Check if message already exists to avoid duplicates
        final messageText = messageData['text'] ?? '';
        final isDuplicate = widget.conversation.messages.any((msg) =>
        msg.text == messageText &&
            msg.senderAtSign == notification.from &&
            msg.timestamp.difference(DateTime.now()).abs().inSeconds < 5
        );

        final messageKeyId = notification.key;

        if (!isDuplicate && messageText.isNotEmpty) {
          setState(() {
            widget.conversation.messages.add(ChatMessage(
              id: messageKeyId,
              text: messageText,
              isMe: false,
              timestamp: DateTime.parse(messageData['timestamp'] ?? DateTime.now().toIso8601String()),
              senderAtSign: notification.from,
            ));
          });

          _scrollToBottom();
        }
      } catch (e) {
        _logger.severe('Error handling incoming message in chat detail: $e');
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final messageText = _messageController.text.trim();
    _messageController.clear();

    try {
      final atClient = atClientManager?.atClient;
      if (atClient == null) {
        _showError('Messaging service not available');
        return;
      }

      // Create unique message key id
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final messageKeyId = 'message.$timestamp';

      final message = ChatMessage(
        id: messageKeyId,
        text: messageText,
        isMe: true,
        timestamp: DateTime.now(),
        senderAtSign: widget.currentAtSign,
      );

      setState(() {
        widget.conversation.messages.add(message);
      });
      _scrollToBottom();

      // Create unique message key with timestamp
      final messageKey = AtKey()
        ..key = messageKeyId
        ..namespace = dotenv.env['NAMESPACE_CHAT']
        ..sharedWith = widget.conversation.otherAtSign
        ..sharedBy = widget.currentAtSign;

      // Set metadata
      final metadata = Metadata()
        ..isPublic = false
        ..isEncrypted = true
        ..namespaceAware = true;

      messageKey.metadata = metadata;

      final messageData = {
        'text': messageText,
        'timestamp': message.timestamp.toIso8601String(),
        'type': 'text',
        'senderAtSign': widget.currentAtSign,
      };
      PutRequestOptions pro = PutRequestOptions()..useRemoteAtServer = true;

      // First, store the message
      await atClient.put(messageKey, jsonEncode(messageData), putRequestOptions: pro);

      // 
      //Then send a notification for real-time update
      /*
      final notificationKey = AtKey()
        ..key = 'notify.message.$timestamp'
        ..namespace = dotenv.env['NAMESPACE_CHAT']
        ..sharedWith = widget.conversation.otherAtSign
        ..sharedBy = widget.currentAtSign;

      // Set notification metadata with TTL
      final notificationMetadata = Metadata()
        ..isPublic = false
        ..isEncrypted = true
        ..namespaceAware = true
        ..ttl = 600000; // 1 minute TTL for notification

      notificationKey.metadata = notificationMetadata;

      // Send notification with the message data
      await atClient.notificationService.notify(
        NotificationParams.forUpdate(
          notificationKey,
          value: jsonEncode(messageData),
        ),
      );*/

      widget.onMessageSent(message);

      // Trigger sync
      atClient.syncService.sync();

      _logger.info('Message sent and notified to ${widget.conversation.otherAtSign}');
    } catch (e) {
      _logger.severe('Error sending message: $e');
      _showError('Failed to send message');

      setState(() {
        widget.conversation.messages.removeLast();
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayName = widget.conversation.otherAtSign.replaceAll('@', '');
    final avatar = displayName.length >= 2
        ? displayName.substring(0, 2).toUpperCase()
        : displayName.toUpperCase();

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, true); // Return true to trigger reload
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              CircleAvatar(
                backgroundColor: _getColorForAtSign(widget.conversation.otherAtSign),
                radius: 20,
                child: Text(
                  avatar,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      widget.conversation.otherAtSign,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 1,
        ),
        body: Column(
          children: [
            Expanded(
              child: widget.conversation.messages.isEmpty
                  ? const Center(
                child: Text(
                  'No messages yet. Start the conversation!',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 16,
                  ),
                ),
              )
                  : ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: widget.conversation.messages.length,
                itemBuilder: (context, index) {
                  return _buildMessage(widget.conversation.messages[index]);
                },
              ),
            ),
            _buildMessageInput(),
          ],
        ),
      ),
    );
  }

  Color _getColorForAtSign(String atSign) {
    final hash = atSign.hashCode;
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.purple,
      Colors.orange,
      Colors.teal,
      Colors.indigo,
      Colors.pink,
      Colors.brown,
    ];
    return colors[hash.abs() % colors.length];
  }

  Widget _buildMessage(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: message.isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.7,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: message.isMe ? Colors.blue : Colors.grey[200],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.text,
                  style: TextStyle(
                    color: message.isMe ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatMessageTime(message.timestamp),
                  style: TextStyle(
                    color: message.isMe
                        ? Colors.white.withOpacity(0.7)
                        : Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatMessageTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return 'now';
    } else if (difference.inHours < 24) {
      return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    } else {
      return '${time.day}/${time.month} ${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    }
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
              textInputAction: TextInputAction.send,
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: Colors.blue,
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white),
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _notificationSubscription?.cancel();
    super.dispose();
  }
}
