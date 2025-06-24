import 'package:flutter/material.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;
  String _searchQuery = '';
  bool _isSearching = false;

  // Sample data
  final List<Map<String, dynamic>> _allPeople = [
    {
      'name': 'John Smith',
      'username': '@johnsmith',
      'avatar': 'JS',
      'color': Colors.blue,
      'isOnline': true,
    },
    {
      'name': 'Sarah Johnson',
      'username': '@sarah_j',
      'avatar': 'SJ',
      'color': Colors.green,
      'isOnline': true,
    },
    {
      'name': 'Emily Davis',
      'username': '@emily_d',
      'avatar': 'ED',
      'color': Colors.orange,
      'isOnline': false,
    },
    {
      'name': 'Mike Wilson',
      'username': '@mike_w',
      'avatar': 'MW',
      'color': Colors.purple,
      'isOnline': true,
    },
    {
      'name': 'Alex Brown',
      'username': '@alex_brown',
      'avatar': 'AB',
      'color': Colors.red,
      'isOnline': false,
    },
    {
      'name': 'Lisa Chen',
      'username': '@lisa_c',
      'avatar': 'LC',
      'color': Colors.teal,
      'isOnline': true,
    },
  ];

  final List<Map<String, dynamic>> _allChats = [
    {
      'name': 'Team Discussion',
      'lastMessage': 'Mike: Let\'s schedule a meeting',
      'time': '1 hour ago',
      'avatar': 'TD',
      'color': Colors.purple,
      'type': 'group',
    },
    {
      'name': 'Project Alpha',
      'lastMessage': 'Sarah: The design is ready',
      'time': '2 hours ago',
      'avatar': 'PA',
      'color': Colors.indigo,
      'type': 'group',
    },
    {
      'name': 'Family Group',
      'lastMessage': 'Mom: Dinner at 7 PM',
      'time': 'Yesterday',
      'avatar': 'FG',
      'color': Colors.pink,
      'type': 'group',
    },
    {
      'name': 'John Smith',
      'lastMessage': 'Hey, how are you doing?',
      'time': '2 min ago',
      'avatar': 'JS',
      'color': Colors.blue,
      'type': 'personal',
    },
  ];

  final List<String> _recentSearches = [
    'Sarah Johnson',
    'Team Discussion',
    'Project Alpha',
    'Emily Davis',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
      _isSearching = _searchQuery.isNotEmpty;
    });
  }

  List<Map<String, dynamic>> _getFilteredPeople() {
    if (_searchQuery.isEmpty) return [];
    return _allPeople.where((person) {
      return person['name'].toLowerCase().contains(_searchQuery.toLowerCase()) ||
             person['username'].toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  List<Map<String, dynamic>> _getFilteredChats() {
    if (_searchQuery.isEmpty) return [];
    return _allChats.where((chat) {
      return chat['name'].toLowerCase().contains(_searchQuery.toLowerCase()) ||
             chat['lastMessage'].toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  List<String> _getFilteredMessages() {
    if (_searchQuery.isEmpty) return [];
    // Simulated message search results
    return [
      'Hey, how are you doing? - John Smith',
      'The project looks great! - Sarah Johnson',
      'Let\'s schedule a meeting - Mike Wilson',
      'Thanks for your help - Emily Davis',
    ].where((message) => 
      message.toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();
  }

  Widget _buildPersonTile(Map<String, dynamic> person) {
    return ListTile(
      leading: Stack(
        children: [
          CircleAvatar(
            backgroundColor: person['color'],
            radius: 24,
            child: Text(
              person['avatar'],
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (person['isOnline'])
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 12,
                height: 12,
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
        person['name'],
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        person['username'],
        style: TextStyle(color: Colors.grey[600]),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.chat, color: Colors.blue),
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Starting chat with ${person['name']}')),
          );
        },
      ),
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Viewing ${person['name']}\'s profile')),
        );
      },
    );
  }

  Widget _buildChatTile(Map<String, dynamic> chat) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: chat['color'],
        radius: 24,
        child: Text(
          chat['avatar'],
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Row(
        children: [
          Text(
            chat['name'],
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          if (chat['type'] == 'group') ...[
            const SizedBox(width: 4),
            Icon(
              Icons.group,
              size: 16,
              color: Colors.grey[600],
            ),
          ],
        ],
      ),
      subtitle: Text(
        chat['lastMessage'],
        style: TextStyle(color: Colors.grey[600]),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        chat['time'],
        style: TextStyle(
          color: Colors.grey[500],
          fontSize: 12,
        ),
      ),
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Opening ${chat['name']}')),
        );
      },
    );
  }

  Widget _buildMessageTile(String message) {
    final parts = message.split(' - ');
    final messageText = parts[0];
    final sender = parts.length > 1 ? parts[1] : '';

    return ListTile(
      leading: const CircleAvatar(
        backgroundColor: Colors.grey,
        radius: 20,
        child: Icon(Icons.message, color: Colors.white, size: 16),
      ),
      title: Text(
        messageText,
        style: const TextStyle(fontWeight: FontWeight.w500),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: sender.isNotEmpty ? Text('from $sender') : null,
      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Opening message: $messageText')),
        );
      },
    );
  }

  Widget _buildRecentSearches() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Searches',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _recentSearches.clear();
                  });
                },
                child: const Text('Clear All'),
              ),
            ],
          ),
        ),
        ..._recentSearches.map((search) => ListTile(
          leading: const Icon(Icons.history, color: Colors.grey),
          title: Text(search),
          trailing: IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () {
              setState(() {
                _recentSearches.remove(search);
              });
            },
          ),
          onTap: () {
            _searchController.text = search;
          },
        )),
      ],
    );
  }

  Widget _buildSearchResults() {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          labelColor: Colors.blue,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blue,
          tabs: const [
            Tab(text: 'People'),
            Tab(text: 'Chats'),
            Tab(text: 'Messages'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // People Tab
              ListView.builder(
                itemCount: _getFilteredPeople().length,
                itemBuilder: (context, index) {
                  return _buildPersonTile(_getFilteredPeople()[index]);
                },
              ),
              // Chats Tab
              ListView.builder(
                itemCount: _getFilteredChats().length,
                itemBuilder: (context, index) {
                  return _buildChatTile(_getFilteredChats()[index]);
                },
              ),
              // Messages Tab
              ListView.builder(
                itemCount: _getFilteredMessages().length,
                itemBuilder: (context, index) {
                  return _buildMessageTile(_getFilteredMessages()[index]);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Container(
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(20),
          ),
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              hintText: 'Search people, chats, messages...',
              prefixIcon: Icon(Icons.search, color: Colors.grey),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            textInputAction: TextInputAction.search,
          ),
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
          if (_isSearching)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                  _isSearching = false;
                });
              },
            ),
        ],
      ),
      body: _isSearching ? _buildSearchResults() : _buildRecentSearches(),
      
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }
}