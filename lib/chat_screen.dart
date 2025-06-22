import 'package:flutter/material.dart';
import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:at_onboarding_flutter/at_onboarding_flutter.dart';
import 'package:at_commons/at_commons.dart';
import 'package:at_utils/at_logger.dart';
import 'dart:async';
import 'dart:convert';
import 'home_screen.dart';
import 'people_screen.dart';
import 'search_screen.dart';
import 'new_enterchat_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  int _selectedIndex = 2;
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

  Future<void> _initializeAtClient() async {
    try {
      // Get the current AtSign if already onboarded
      atClientManager = AtClientManager.getInstance();
      currentAtSign = atClientManager?.atClient.getCurrentAtSign();
      
      if (currentAtSign != null) {
        await _setupNotificationListener();
        await _loadConversations();
      } else {
        // Navigate to onboarding if not authenticated
        _navigateToOnboarding();
      }
    } catch (e) {
      _logger.severe('Error initializing AtClient: $e');
      _showErrorDialog('Failed to initialize messaging service');
    }
  }

  Future<void> _navigateToOnboarding() async {
    final AtOnboardingConfig config = AtOnboardingConfig(
      atClientPreference: AtClientPreference()
        ..rootDomain = 'root.atsign.org'
        ..namespace = 'chatapp'
        ..hiveStoragePath = '/storage/hive'
        ..commitLogPath = '/storage/commitLog'
        ..isLocalStoreRequired = true,
      appAPIKey: 'YOUR_API_KEY', // Replace with your actual API key
      rootEnvironment: RootEnvironment.Production,
    );

    final result = await AtOnboarding.onboard(
      context: context,
      config: config,
    );

    if (result.status == AtOnboardingResultStatus.success) {
      currentAtSign = result.atsign;
      await _setupNotificationListener();
      await _loadConversations();
      setState(() {});
    }
  }

  Future<void> _setupNotificationListener() async {
    try {
      final notificationService = atClientManager?.notificationService;
      if (notificationService != null) {
        _notificationSubscription = notificationService
            .subscribe(regex: 'message\\..*')
            .listen(_handleNotification);
      }
    } catch (e) {
      _logger.severe('Error setting up notification listener: $e');
    }
  }

  void _handleNotification(AtNotification notification) {
  _logger.info('Received notification: ${notification.key}');
  
  if (notification.key.contains('message.')) {
    // Handle both regular messages and self-notifications
    if (notification.key.contains('.self')) {
      // This is a self-notification for cross-device sync
      _processSelfMessage(notification);
    } else {
      // This is a message from another user
      _processIncomingMessage(notification);
    }
  }
}

  Future<void> _processIncomingMessage(AtNotification notification) async {
    try {
      final messageData = jsonDecode(notification.value ?? '{}');
      final senderAtSign = notification.from;
      
      // Find or create conversation
      int conversationIndex = conversations.indexWhere(
        (conv) => conv.otherAtSign == senderAtSign,
      );
      
      if (conversationIndex == -1) {
        // Create new conversation
        conversations.insert(0, ChatConversation(
          otherAtSign: senderAtSign,
          lastMessage: messageData['text'] ?? '',
          lastMessageTime: DateTime.now(),
          unreadCount: 1,
          messages: [],
        ));
        conversationIndex = 0;
      } else {
        // Update existing conversation
        conversations[conversationIndex].lastMessage = messageData['text'] ?? '';
        conversations[conversationIndex].lastMessageTime = DateTime.now();
        conversations[conversationIndex].unreadCount++;
        
        // Move to top
        final conversation = conversations.removeAt(conversationIndex);
        conversations.insert(0, conversation);
      }
      
      // Add message to conversation
      conversations[0].messages.add(ChatMessage(
        text: messageData['text'] ?? '',
        isMe: false,
        timestamp: DateTime.now(),
        senderAtSign: senderAtSign,
      ));
      
      setState(() {});
    } catch (e) {
      _logger.severe('Error processing incoming message: $e');
    }
  }

  Future<void> _processSelfMessage(AtNotification notification) async {
  // Handle messages sent from your other devices
  try {
    final messageData = jsonDecode(notification.value ?? '{}');
    
    // Extract recipient from the message data
    String? recipientAtSign = messageData['recipientAtSign'] ?? 
                             messageData['originalRecipient'] ?? 
                             notification.to;
    
    // Verify this is actually a self-notification
    bool isSelfNotification = messageData['isSelfNotification'] == true ||
                             notification.key.contains('.self');
    
    if (!isSelfNotification) {
      _logger.warning('Received non-self message in self processor');
      return;
    }
    
    if (recipientAtSign == null || recipientAtSign.isEmpty) {
      _logger.warning('Could not determine recipient for self message');
      return;
    }
    
    // Find or create conversation with the recipient
    int conversationIndex = conversations.indexWhere(
      (conv) => conv.otherAtSign == recipientAtSign,
    );
    
    ChatConversation targetConversation;
    
    if (conversationIndex == -1) {
      // Create new conversation if it doesn't exist
      targetConversation = ChatConversation(
        otherAtSign: recipientAtSign,
        lastMessage: messageData['text'] ?? '',
        lastMessageTime: DateTime.parse(
          messageData['timestamp'] ?? DateTime.now().toIso8601String()
        ),
        unreadCount: 0, // Don't mark your own messages as unread
        messages: [],
      );
      conversations.insert(0, targetConversation);
      conversationIndex = 0;
    } else {
      // Update existing conversation
      targetConversation = conversations[conversationIndex];
      targetConversation.lastMessage = messageData['text'] ?? '';
      targetConversation.lastMessageTime = DateTime.parse(
        messageData['timestamp'] ?? DateTime.now().toIso8601String()
      );
      
      // Move conversation to top of list
      conversations.removeAt(conversationIndex);
      conversations.insert(0, targetConversation);
      conversationIndex = 0;
    }
    
    // Create the message object
    final message = ChatMessage(
      text: messageData['text'] ?? '',
      isMe: true, // This is your message from another device
      timestamp: DateTime.parse(
        messageData['timestamp'] ?? DateTime.now().toIso8601String()
      ),
      senderAtSign: currentAtSign!, // You sent this message
    );
    
    // Check if this message already exists to avoid duplicates
    bool messageExists = targetConversation.messages.any(
      (existingMessage) => 
        existingMessage.text == message.text && 
        existingMessage.timestamp.difference(message.timestamp).abs().inSeconds < 5 &&
        existingMessage.isMe == message.isMe
    );
    
    if (!messageExists) {
      // Add message to conversation in chronological order
      targetConversation.messages.add(message);
      
      // Sort messages by timestamp to maintain order
      targetConversation.messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      
      // Save the updated conversation
      await _saveConversation(targetConversation);
      
      _logger.info('Added self message to conversation with $recipientAtSign');
    } else {
      _logger.info('Self message already exists, skipping duplicate');
    }
    
    // Update UI with your own message from another device
    setState(() {
      // The conversations list and messages are already updated above
      // This setState will trigger a rebuild to show the new message
    });
    
  } catch (e) {
    _logger.severe('Error processing self message: $e');
    
    // Show user-friendly error if needed
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to sync message from another device'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}

  Future<void> _loadConversations() async {
    try {
      final atClient = atClientManager?.atClient;
      if (atClient == null) return;
      
      // Load conversation keys from atServer
      final keys = await atClient.getKeys(regex: 'conversation.*');
      
      for (String key in keys) {
        try {
          final atValue = await atClient.get(AtKey.fromString(key));
          if (atValue.value != null) {
            final conversationData = jsonDecode(atValue.value!);
            final conversation = ChatConversation.fromJson(conversationData);
            conversations.add(conversation);
          }
        } catch (e) {
          _logger.warning('Error loading conversation $key: $e');
        }
      }
      
      // Sort conversations by last message time
      conversations.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
      setState(() {});
    } catch (e) {
      _logger.severe('Error loading conversations: $e');
    }
  }

  Future<void> _saveConversation(ChatConversation conversation) async {
    try {
      final atClient = atClientManager?.atClient;
      if (atClient == null) return;
      
      final key = AtKey()
        ..key = 'conversation.${conversation.otherAtSign.replaceAll('@', '')}'
        ..namespace = 'chatapp'
        ..sharedBy = currentAtSign;
      
      await atClient.put(key, jsonEncode(conversation.toJson()));
    } catch (e) {
      _logger.severe('Error saving conversation: $e');
    }
  }

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;
    
    Widget screen;
    switch (index) {
      case 0:
        screen = const HomeScreen();
        break;
      case 1:
        screen = const PeopleScreen();
        break;
      case 2:
        return; // Already on chat screen
      case 3:
        screen = const SearchScreen();
        break;
      default:
        return;
    }
    
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
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
    // Find existing conversation or create new one
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

  void _openChat(ChatConversation conversation) {
    // Mark as read
    conversation.unreadCount = 0;
    setState(() {});
    
    Navigator.push(
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

  ChatConversation({
    required this.otherAtSign,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.unreadCount,
    required this.messages,
  });

  Map<String, dynamic> toJson() {
    return {
      'otherAtSign': otherAtSign,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime.toIso8601String(),
      'unreadCount': unreadCount,
      'messages': messages.map((m) => m.toJson()).toList(),
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
    );
  }
}

class ChatMessage {
  String text;
  bool isMe;
  DateTime timestamp;
  String senderAtSign;

  ChatMessage({
    required this.text,
    required this.isMe,
    required this.timestamp,
    required this.senderAtSign,
  });

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'isMe': isMe,
      'timestamp': timestamp.toIso8601String(),
      'senderAtSign': senderAtSign,
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      text: json['text'] ?? '',
      isMe: json['isMe'] ?? false,
      timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
      senderAtSign: json['senderAtSign'] ?? '',
    );
  }
}

// Chat Detail Screen - Individual chat conversation
class ChatDetailScreen extends StatefulWidget {
  final ChatConversation conversation;
  final String currentAtSign;
  final Function(ChatMessage) onMessageSent;

  const ChatDetailScreen({
    Key? key,
    required this.conversation,
    required this.currentAtSign,
    required this.onMessageSent,
  }) : super(key: key);

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  AtClientManager? atClientManager;
  final AtSignLogger _logger = AtSignLogger('ChatDetailScreen');

  @override
  void initState() {
    super.initState();
    atClientManager = AtClientManager.getInstance();
    _scrollToBottom();
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

      // Create message object
      final message = ChatMessage(
        text: messageText,
        isMe: true,
        timestamp: DateTime.now(),
        senderAtSign: widget.currentAtSign,
      );

      // Add to local conversation immediately for immediate UI feedback
      setState(() {
        widget.conversation.messages.add(message);
      });
      _scrollToBottom();

      // Send to atServer
      final messageKey = AtKey()
        ..key = 'message.${DateTime.now().millisecondsSinceEpoch}'
        ..namespace = 'chatapp'
        ..sharedWith = widget.conversation.otherAtSign
        ..sharedBy = widget.currentAtSign;

      final messageData = {
        'text': messageText,
        'timestamp': message.timestamp.toIso8601String(),
        'type': 'text',
      };

      await atClient.put(messageKey, jsonEncode(messageData));

          // Also notify yourself for cross-device sync
      final selfNotificationKey = AtKey()
        ..key = 'message.${DateTime.now().millisecondsSinceEpoch}.self'
        ..namespace = 'chatapp'
        ..sharedWith = widget.currentAtSign  // Send to yourself
        ..sharedBy = widget.currentAtSign;
    
      await atClient.put(selfNotificationKey, jsonEncode(messageData));
      
      // Notify parent to update conversation list
      widget.onMessageSent(message);

      try {
        atClientManager?.atClient.syncService;
      } catch (e) {
        _logger.warning('Sync failed: $e');
      }

      _logger.info('Message sent successfully to ${widget.conversation.otherAtSign}');
    } catch (e) {
      _logger.severe('Error sending message: $e');
      _showError('Failed to send message');
      
      // Remove the message from local list if sending failed
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

    return Scaffold(
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
            color: Colors.grey.withOpacity(0.1),
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
    super.dispose();
  }
}

// Create Group Screen
class CreateGroupScreen extends StatelessWidget {
  const CreateGroupScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Group'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.group_add,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'Group Chat',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Group messaging feature coming soon!',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Archived Chats Screen
class ArchivedChatsScreen extends StatelessWidget {
  const ArchivedChatsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Archived Chats'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.archive,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'No archived chats',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Archived conversations will appear here',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Chat Search Screen
class ChatSearchScreen extends StatefulWidget {
  const ChatSearchScreen({Key? key}) : super(key: key);

  @override
  State<ChatSearchScreen> createState() => _ChatSearchScreenState();
}

class _ChatSearchScreenState extends State<ChatSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<String> searchResults = [];

  void _performSearch(String query) {
    // Implement search functionality here
    // This could search through conversation history, contact names, etc.
    setState(() {
      searchResults = []; // Placeholder for search results
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: 'Search chats...',
            border: InputBorder.none,
          ),
          onChanged: _performSearch,
          autofocus: true,
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: searchResults.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Search your chats',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Enter a search term to find messages',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: searchResults.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(searchResults[index]),
                );
              },
            ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}