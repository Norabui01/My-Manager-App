import 'package:flutter/material.dart';
import 'chat_screen.dart';

class PeopleScreen extends StatefulWidget {
  const PeopleScreen({super.key});

  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'People',
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
            icon: const Icon(Icons.person_add),
            onPressed: () {
              _showAddPersonDialog();
            },
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Search functionality coming soon!')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats Section
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    title: 'Total Contacts',
                    value: '152',
                    icon: Icons.people,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    title: 'Team Members',
                    value: '8',
                    icon: Icons.group,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Team Members Section
            const Text(
              'Team Members',
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
                  _buildPersonItem(
                    name: 'John Smith',
                    role: 'Manager',
                    avatar: 'JS',
                    color: Colors.blue,
                    isOnline: true,
                  ),
                  const Divider(height: 1),
                  _buildPersonItem(
                    name: 'Sarah Johnson',
                    role: 'Developer',
                    avatar: 'SJ',
                    color: Colors.green,
                    isOnline: true,
                  ),
                  const Divider(height: 1),
                  _buildPersonItem(
                    name: 'Mike Davis',
                    role: 'Designer',
                    avatar: 'MD',
                    color: Colors.orange,
                    isOnline: false,
                  ),
                  const Divider(height: 1),
                  _buildPersonItem(
                    name: 'Emily Wilson',
                    role: 'Marketing',
                    avatar: 'EW',
                    color: Colors.purple,
                    isOnline: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Recent Contacts Section
            const Text(
              'Recent Contacts',
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
                  _buildPersonItem(
                    name: 'Alice Brown',
                    role: 'Customer',
                    avatar: 'AB',
                    color: Colors.teal,
                    isOnline: false,
                    showLastSeen: true,
                    lastSeen: '2 hours ago',
                  ),
                  const Divider(height: 1),
                  _buildPersonItem(
                    name: 'Robert Taylor',
                    role: 'Supplier',
                    avatar: 'RT',
                    color: Colors.indigo,
                    isOnline: false,
                    showLastSeen: true,
                    lastSeen: '1 day ago',
                  ),
                  const Divider(height: 1),
                  _buildPersonItem(
                    name: 'Lisa Anderson',
                    role: 'Partner',
                    avatar: 'LA',
                    color: Colors.pink,
                    isOnline: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: "dialog_fab", //add hero tag to prevent hero conflicts
        onPressed: _showAddPersonDialog,
        backgroundColor: Colors.blue[600],
        child: const Icon(Icons.person_add, color: Colors.white),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const Spacer(),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonItem({
    required String name,
    required String role,
    required String avatar,
    required Color color,
    required bool isOnline,
    bool showLastSeen = false,
    String? lastSeen,
  }) {
    return ListTile(
      leading: Stack(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.1),
            child: Text(
              avatar,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (isOnline)
            Positioned(
              right: 0,
              bottom: 0,
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
        name,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        showLastSeen && lastSeen != null ? '$role • Last seen $lastSeen' : role,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.chat, size: 20),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ChatScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, size: 20),
            onPressed: () {
              _showPersonOptions(name);
            },
          ),
        ],
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }

  void _showAddPersonDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add New Contact'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Role/Title',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                decoration: InputDecoration(
                  labelText: '@sign',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Contact added successfully!')),
                );
              },
              child: const Text('Add Contact'),
            ),
          ],
        );
      },
    );
  }

  void _showPersonOptions(String name) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.chat),
                title: const Text('Send Message'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ChatScreen()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.call),
                title: const Text('Call'),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Calling functionality coming soon!')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit Contact'),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Edit contact coming soon!')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete Contact', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Delete contact coming soon!')),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}