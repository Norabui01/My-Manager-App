import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'people_screen.dart';
import 'search_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  int _selectedIndex = 2;
  final TextEditingController _messageController = TextEditingController();

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
            ],
          ),
        );
      },
    );
  }

  void _startNewChat() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Starting new chat...')),
    );
  }

  void _createGroup() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Creating new group...')),
    );
  }

  void _showArchivedChats() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Showing archived chats...')),
    );
  }

  Widget _buildChatItem({
    required String name,
    required String lastMessage,
    required String time,
    required String avatar,
    required Color color,
    bool isOnline = false,
    int unreadCount = 0,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Stack(
        children: [
          CircleAvatar(
            backgroundColor: color,
            radius: 24,
            child: Text(
              avatar,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (isOnline)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
        ],
      ),
      title: Text(
        name,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
      subtitle: Text(
        lastMessage,
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
            time,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 12,
            ),
          ),
          if (unreadCount > 0) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                unreadCount.toString(),
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
      onTap: () {
        _openChat(name);
      },
    );
  }

  void _openChat(String name) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Opening chat with $name')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Chat',
          style: TextStyle(fontWeight: FontWeight.bold),
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Search chats coming soon!')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              _showChatOptions();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Chat List Section
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Active Chats Section
                  const Text(
                    'Active Chats',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      children: [
                        _buildChatItem(
                          name: 'John Smith',
                          lastMessage: 'Hey, how are you doing?',
                          time: '2 min ago',
                          avatar: 'JS',
                          color: Colors.blue,
                          isOnline: true,
                          unreadCount: 2,
                        ),
                        const Divider(height: 1),
                        _buildChatItem(
                          name: 'Sarah Johnson',
                          lastMessage: 'The project looks great!',
                          time: '10 min ago',
                          avatar: 'SJ',
                          color: Colors.green,
                          isOnline: true,
                          unreadCount: 0,
                        ),
                        const Divider(height: 1),
                        _buildChatItem(
                          name: 'Team Discussion',
                          lastMessage: 'Mike: Let\'s schedule a meeting',
                          time: '1 hour ago',
                          avatar: 'TD',
                          color: Colors.purple,
                          isOnline: false,
                        ),
                        const Divider(height: 1),
                        _buildChatItem(
                          name: 'Emily Davis',
                          lastMessage: 'Thanks for your help yesterday!',
                          time: '3 hours ago',
                          avatar: 'ED',
                          color: Colors.orange,
                          isOnline: false,
                          unreadCount: 1,
                        ),
                        const Divider(height: 1),
                        _buildChatItem(
                          name: 'Family Group',
                          lastMessage: 'Mom: Dinner at 7 PM',
                          time: 'Yesterday',
                          avatar: 'FG',
                          color: Colors.teal,
                          isOnline: false,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Recent Chats Section
                  const Text(
                    'Recent',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      children: [
                        _buildChatItem(
                          name: 'Alex Wilson',
                          lastMessage: 'See you at the conference!',
                          time: '2 days ago',
                          avatar: 'AW',
                          color: Colors.indigo,
                          isOnline: false,
                        ),
                        const Divider(height: 1),
                        _buildChatItem(
                          name: 'Marketing Team',
                          lastMessage: 'Lisa: Campaign results are in',
                          time: '3 days ago',
                          avatar: 'MT',
                          color: Colors.pink,
                          isOnline: false,
                        ),
                        const Divider(height: 1),
                        _buildChatItem(
                          name: 'David Brown',
                          lastMessage: 'Got it, thanks!',
                          time: '1 week ago',
                          avatar: 'DB',
                          color: Colors.brown,
                          isOnline: false,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
    super.dispose();
  }
}