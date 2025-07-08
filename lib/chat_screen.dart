import 'package:flutter/material.dart';
import 'package:at_onboarding_flutter/at_onboarding_flutter.dart';
import 'package:at_utils/at_logger.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:async';
import 'dart:convert';
import 'onboarding_configuration.dart';

import 'new_enterchat_screen.dart';
import 'individual_chat_screen.dart';
import 'group_chat_screen.dart';
import 'search_chat_screen.dart';
import 'archived_chat_screen.dart';


class ChatScreen extends StatefulWidget {
  final VoidCallback onBackToHome;
  const ChatScreen({
    super.key,
    required this.onBackToHome});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  AtClientManager? atClientManager;
  String? currentAtSign;
  List<ChatConversation> conversations = [];
  StreamSubscription<AtNotification>? _notificationSubscription;
  final AtSignLogger _logger = AtSignLogger('ChatScreen');

  @override
  void initState() {
    super.initState();
    _initializeAtClient();
  }

  Future<void> _navigateToOnboarding() async {
    await OnboardingConfig.onboardUser(
      context: context,
      apiKey: dotenv.env['API_KEY'],
      namespace: dotenv.env['NAMESPACE_CHAT'],
      onSuccess: (atSign) async {
        currentAtSign = atSign;
        await _setupNotificationListener();
        await _loadConversations();
        setState(() {});
      }
    );
  }

  Future<void> _initializeAtClient() async {
    try {
      atClientManager = AtClientManager.getInstance();
      currentAtSign = atClientManager?.atClient.getCurrentAtSign();

      if (currentAtSign != null) {
        await _setupNotificationListener();
        await _loadConversations();
      } else {
        await _navigateToOnboarding();
      }
    } catch (e) {
      _logger.severe('Error initializing AtClient: $e');
      _showErrorDialog('Failed to initialize messaging service');
    }
  }

  Future<void> _setupNotificationListener() async {
    try {
      final notificationService = atClientManager?.atClient.notificationService;
      if (notificationService != null) {
        _notificationSubscription = notificationService
            .subscribe(regex: '.*', shouldDecrypt: true)
            .listen((notification) {
          _logger.info('Notification received: ${notification.key}');
          _handleNotification(notification);
        }, onError: (e) {
          _logger.severe('Notification error: $e');
        });

        _logger.info('Notification listener setup complete');
      }
    } catch (e) {
      _logger.severe('Error setting up notification listener: $e');
    }
  }

  void _handleNotification(AtNotification notification) {
    //skip system sync/stat pings
    if (notification.key.contains('statsNotification')) return;
    _logger.info('Handling notification: ${notification.key} from ${notification.from}');

    // Handle both stored messages and notifications
    if (notification.key.contains('message.') || notification.key.contains('notify.message.')) {
      _processIncomingMessage(notification);
      
    }
  }

  Future<void> _processIncomingMessage(AtNotification notification) async {
    try {
      // Skip if this is our own message
      if (notification.from == currentAtSign) {
        return;
      }

      final messageData = jsonDecode(notification.value ?? '{}');
      final senderAtSign = notification.from;

      _logger.info('Processing message from $senderAtSign: ${messageData['text']}');

      // Find or create conversation
      int conversationIndex = conversations.indexWhere(
            (conv) => conv.otherAtSign == senderAtSign,
      );

      if (conversationIndex == -1) {
        conversations.insert(0, ChatConversation(
          otherAtSign: senderAtSign,
          lastMessage: messageData['text'] ?? '',
          lastMessageTime: DateTime.parse(messageData['timestamp'] ?? DateTime.now().toIso8601String()),
          unreadCount: 1,
          messages: [],
        ));
        conversationIndex = 0;
      } else {
        conversations[conversationIndex].lastMessage = messageData['text'] ?? '';
        conversations[conversationIndex].lastMessageTime = DateTime.parse(
            messageData['timestamp'] ?? DateTime.now().toIso8601String()
        );
        conversations[conversationIndex].unreadCount++;

        final conversation = conversations.removeAt(conversationIndex);
        conversations.insert(0, conversation);
      }

      // Add message to conversation
      final newMessage = ChatMessage(
        id: notification.key,
        text: messageData['text'] ?? '',
        isMe: false,
        timestamp: DateTime.parse(messageData['timestamp'] ?? DateTime.now().toIso8601String()),
        senderAtSign: senderAtSign,
      );

      // Check for duplicates before adding
      final isDuplicate = conversations[0].messages.any((msg) =>
      msg.text == newMessage.text &&
          msg.senderAtSign == newMessage.senderAtSign &&
          msg.timestamp.difference(newMessage.timestamp).abs().inSeconds < 5
      );

      if (!isDuplicate) {
        conversations[0].messages.add(newMessage);
        await _saveConversation(conversations[0]);
      }

      setState(() {});
    } catch (e) {
      _logger.severe('Error processing incoming message: $e');
    }
  }

  Future<void> _loadConversations() async {
    try {
      final atClient = atClientManager?.atClient;
      if (atClient == null) return;

      conversations.clear();

      // Load conversation keys
      final keys = await atClient.getKeys(regex: 'conversation\\..*');

      for (String key in keys) {
        try {
          final atKey = AtKey.fromString(key);
          atKey.sharedBy = currentAtSign;

          final atValue = await atClient.get(atKey);
          if (atValue.value != null) {
            final conversationData = jsonDecode(atValue.value!);
            final conversation = ChatConversation.fromJson(conversationData);

            // Also load messages for this conversation
            await _loadMessagesForConversation(conversation);

            conversations.add(conversation);
          }
        } catch (e) {
          _logger.warning('Error loading conversation $key: $e');
        }
      }

      conversations.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
      setState(() {});
    } catch (e) {
      _logger.severe('Error loading conversations: $e');
    }
  }

  Future<void> _loadMessagesForConversation(ChatConversation conversation) async {
    try {
      final atClient = atClientManager?.atClient;
      if (atClient == null) return;

      conversation.messages.clear();

      // Load messages shared with the other person
      final sharedKeys = await atClient.getKeys(
        regex: 'message\\..*',
        sharedWith: conversation.otherAtSign,
      );

      // Load messages shared by the other person
      final receivedKeys = await atClient.getKeys(
        regex: 'message\\..*',
        sharedBy: conversation.otherAtSign,
      );

      // Process all messages
      final allKeys = {...sharedKeys, ...receivedKeys};
      final existingIds = <String>{};

      for (String key in allKeys) {
        
        try {
          if (existingIds.contains(key)) continue;
          final atKey = AtKey.fromString(key);

          // Set proper metadata
          if (sharedKeys.contains(key)) {
            atKey.sharedBy = currentAtSign;
            atKey.sharedWith = conversation.otherAtSign;
          } else {
            atKey.sharedBy = conversation.otherAtSign;
            atKey.sharedWith = currentAtSign;
          }

          final atValue = await atClient.get(atKey);
          if (atValue.value != null) {
            final messageData = jsonDecode(atValue.value!);

            final text = messageData['text'] ?? '';
            final timestampStr = messageData['timestamp'] ?? DateTime.now().toIso8601String();
            final timestamp = DateTime.parse(timestampStr);
            final sender = atKey.sharedBy!;

            bool isDuplicate = conversation.messages.any((msg) =>
              msg.text == text &&
              msg.senderAtSign == sender &&
              msg.timestamp == timestamp
            );

            if (!isDuplicate) {
              conversation.messages.add(ChatMessage(
                id: key,
                text: text,
                isMe: sender == currentAtSign,
                timestamp: timestamp,
                senderAtSign: sender,
              ));
              existingIds.add(key);
            }

            /*conversation.messages.add(ChatMessage(
              id: key,
              text: messageData['text'] ?? '',
              isMe: atKey.sharedBy == currentAtSign,
              timestamp: DateTime.parse(messageData['timestamp'] ?? DateTime.now().toIso8601String()),
              senderAtSign: atKey.sharedBy!,
            ));
            existingIds.add(key);*/ // prevent duplication
          }
        } catch (e) {
          _logger.warning('Error loading message $key: $e');
        }
      }

      // Sort messages by timestamp
      conversation.messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    } catch (e) {
      _logger.severe('Error loading messages for conversation: $e');
    }
  }

  Future<void> _saveConversation(ChatConversation conversation) async {
    PutRequestOptions pro = PutRequestOptions()..useRemoteAtServer = true;
    try {
      final atClient = atClientManager?.atClient;
      if (atClient == null) return;

      final key = AtKey()
        ..key = 'conversation.${conversation.otherAtSign.replaceAll('@', '')}'
        ..namespace = 'chatapp'
        ..sharedBy = currentAtSign;

      await atClient.put(key, jsonEncode(conversation.toJson()), putRequestOptions: pro);
    } catch (e) {
      _logger.severe('Error saving conversation: $e');
    }
  }

  void _showChatOptions() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('New Chat'),
                onTap: () {
                  Navigator.pop(context);
                  _startNewChat();
                },
              ),
              ListTile(
                leading: const Icon(Icons.group_add),
                title: const Text('New Group'),
                onTap: () {
                  Navigator.pop(context);
                  _createGroup();
                },
              ),
              ListTile(
                leading: const Icon(Icons.archive),
                title: const Text('Archived Chats'),
                onTap: () {
                  Navigator.pop(context);
                  _showArchivedChats();
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Switch AtSign'),
                onTap: () {
                  Navigator.pop(context);
                  _switchAtSign();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _startNewChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NewChatScreen(
          onChatStarted: (String atSign) {
            _openChatWithAtSign(atSign);
          },
        ),
      ),
    );
  }

  void _openChatWithAtSign(String atSign) {
    ChatConversation? conversation = conversations
        .cast<ChatConversation?>()
        .firstWhere(
          (conv) => conv?.otherAtSign == atSign,
      orElse: () => null,
    );

    if (conversation == null) {
      conversation = ChatConversation(
        otherAtSign: atSign,
        lastMessage: '',
        lastMessageTime: DateTime.now(),
        unreadCount: 0,
        messages: [],
      );
      conversations.insert(0, conversation);
    }

    _openChat(conversation);
  }

  void _createGroup() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateGroupScreen(),
      ),
    );
  }

  void _showArchivedChats() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ArchivedChatsScreen(),
      ),
    );
  }

  void _switchAtSign() async {
    AtClientManager.getInstance().reset();
    currentAtSign = null;
    conversations.clear();
    setState(() {});
    _navigateToOnboarding();
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildChatItem(ChatConversation conversation) {
    final displayName = conversation.otherAtSign.replaceAll('@', '');
    final avatar = displayName.length >= 2
        ? displayName.substring(0, 2).toUpperCase()
        : displayName.toUpperCase();

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        backgroundColor: _getColorForAtSign(conversation.otherAtSign),
        radius: 24,
        child: Text(
          avatar,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        displayName,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
      subtitle: Text(
        conversation.lastMessage.isEmpty
            ? 'No messages yet'
            : conversation.lastMessage,
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 14,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _formatTime(conversation.lastMessageTime),
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 12,
            ),
          ),
          if (conversation.unreadCount > 0) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                conversation.unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
      onTap: () => _openChat(conversation),
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

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return 'now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${time.day}/${time.month}/${time.year}';
    }
  }

  void _openChat(ChatConversation conversation) async {
    conversation.unreadCount = 0;
    setState(() {});

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatDetailScreen(
          conversation: conversation,
          currentAtSign: currentAtSign!,
          onMessageSent: (message) {
            conversation.messages.add(message);
            conversation.lastMessage = message.text;
            conversation.lastMessageTime = message.timestamp;
            _saveConversation(conversation);
            setState(() {});
          },
        ),
      ),
    );

    // Reload messages when returning from chat detail
    if (result == true) {
      await Future.delayed(Duration(seconds: 1)); // prevent race with sync
      await _loadMessagesForConversation(conversation);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (currentAtSign == null) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        leading: BackButton(
          onPressed: () {
          widget.onBackToHome(); // switch tab to HomeScreen
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Chat',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              currentAtSign!,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: Colors.grey[200],
            height: 1,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ChatSearchScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: _showChatOptions,
          ),
        ],
      ),
      body: conversations.isEmpty
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'No conversations yet',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Start a new chat to begin messaging',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: conversations.length,
        itemBuilder: (context, index) {
          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey[200]!),
            ),
            child: _buildChatItem(conversations[index]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: "newchat_fab", 
        onPressed: _startNewChat,
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _notificationSubscription?.cancel();
    super.dispose();
  }
}

// Data Models
class ChatConversation {
  String otherAtSign;
  String lastMessage;
  DateTime lastMessageTime;
  int unreadCount;
  List<ChatMessage> messages;

  Set<String> seenIds;

  ChatConversation({
    required this.otherAtSign,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.unreadCount,
    required this.messages,
    Set<String>? seenIds,
  }) : seenIds = seenIds ?? {}; 

  Map<String, dynamic> toJson() {
    return {
      'otherAtSign': otherAtSign,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime.toIso8601String(),
      'unreadCount': unreadCount,
      'messages': messages.map((m) => m.toJson()).toList(),
      'seenIds': seenIds.toList(), // serialize seen IDs
    };
  }

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    return ChatConversation(
      otherAtSign: json['otherAtSign'] ?? '',
      lastMessage: json['lastMessage'] ?? '',
      lastMessageTime: DateTime.parse(json['lastMessageTime'] ?? DateTime.now().toIso8601String()),
      unreadCount: json['unreadCount'] ?? 0,
      messages: (json['messages'] as List<dynamic>?)
          ?.map((m) => ChatMessage.fromJson(m))
          .toList() ?? [],
          seenIds: json['seenIds'] != null
        ? Set<String>.from(json['seenIds'])
        : <String>{},
    );
  }
}

class ChatMessage {
  String id;
  String text;
  bool isMe;
  DateTime timestamp;
  String senderAtSign;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isMe,
    required this.timestamp,
    required this.senderAtSign,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'isMe': isMe,
      'timestamp': timestamp.toIso8601String(),
      'senderAtSign': senderAtSign,
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] ?? '',
      text: json['text'] ?? '',
      isMe: json['isMe'] ?? false,
      timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
      senderAtSign: json['senderAtSign'] ?? '',
    );
  }
}

// Chat Detail Screen - Individual chat conversation

// Create Group Screen//unnessary

// Archived Chats Screen//Unnessary 

// Chat Search Screen//unnessary
