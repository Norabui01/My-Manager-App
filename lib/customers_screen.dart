import 'package:flutter/material.dart';

class Customer {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String company;
  final String avatar;
  final DateTime lastOrder;
  final double totalSpent;
  final String status;

  Customer({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.company,
    required this.avatar,
    required this.lastOrder,
    required this.totalSpent,
    required this.status,
  });
}

class CustomersListScreen extends StatefulWidget {
  const CustomersListScreen({Key? key}) : super(key: key);

  @override
  State<CustomersListScreen> createState() => _CustomersListScreenState();
}

class _CustomersListScreenState extends State<CustomersListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All';
  List<Customer> _customers = [];
  List<Customer> _filteredCustomers = [];

  @override
  void initState() {
    super.initState();
    _loadCustomers();
    _searchController.addListener(_filterCustomers);
  }

  void _loadCustomers() {
    // Sample data - replace with your data source
    _customers = [
      Customer(
        id: '1',
        name: 'John Smith',
        email: 'john.smith@email.com',
        phone: '+1 234 567 8900',
        company: 'Tech Solutions Inc.',
        avatar: 'https://api.dicebear.com/7.x/avataaars/png?seed=John',
        lastOrder: DateTime.now().subtract(const Duration(days: 5)),
        totalSpent: 12450.00,
        status: 'Active',
      ),
      Customer(
        id: '2',
        name: 'Sarah Johnson',
        email: 'sarah.j@email.com',
        phone: '+1 234 567 8901',
        company: 'Design Studio',
        avatar: 'https://api.dicebear.com/7.x/avataaars/png?seed=Sarah',
        lastOrder: DateTime.now().subtract(const Duration(days: 12)),
        totalSpent: 8900.00,
        status: 'Active',
      ),
      Customer(
        id: '3',
        name: 'Mike Chen',
        email: 'mike.chen@email.com',
        phone: '+1 234 567 8902',
        company: 'StartupXYZ',
        avatar: 'https://api.dicebear.com/7.x/avataaars/png?seed=Mike',
        lastOrder: DateTime.now().subtract(const Duration(days: 45)),
        totalSpent: 5600.00,
        status: 'Inactive',
      ),
      Customer(
        id: '4',
        name: 'Emily Davis',
        email: 'emily.davis@email.com',
        phone: '+1 234 567 8903',
        company: 'Marketing Pro',
        avatar: 'https://api.dicebear.com/7.x/avataaars/png?seed=Emily',
        lastOrder: DateTime.now().subtract(const Duration(days: 2)),
        totalSpent: 15300.00,
        status: 'VIP',
      ),
      Customer(
        id: '5',
        name: 'David Wilson',
        email: 'david.w@email.com',
        phone: '+1 234 567 8904',
        company: 'Consulting Group',
        avatar: 'https://api.dicebear.com/7.x/avataaars/png?seed=David',
        lastOrder: DateTime.now().subtract(const Duration(days: 8)),
        totalSpent: 9800.00,
        status: 'Active',
      ),
    ];
    _filteredCustomers = _customers;
  }

  void _filterCustomers() {
    setState(() {
      _filteredCustomers = _customers.where((customer) {
        final matchesSearch = customer.name
                .toLowerCase()
                .contains(_searchController.text.toLowerCase()) ||
            customer.email
                .toLowerCase()
                .contains(_searchController.text.toLowerCase()) ||
            customer.company
                .toLowerCase()
                .contains(_searchController.text.toLowerCase());

        final matchesFilter = _selectedFilter == 'All' ||
            customer.status == _selectedFilter;

        return matchesSearch && matchesFilter;
      }).toList();
    });
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Active':
        return Colors.green;
      case 'VIP':
        return Colors.purple;
      case 'Inactive':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Customers',
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
            icon: const Icon(Icons.add),
            onPressed: () {
              // Add new customer functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Add new customer')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter Section
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search customers...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                ),
                const SizedBox(height: 12),
                // Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['All', 'Active', 'VIP', 'Inactive']
                        .map((filter) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(filter),
                                selected: _selectedFilter == filter,
                                onSelected: (selected) {
                                  setState(() {
                                    _selectedFilter = filter;
                                    _filterCustomers();
                                  });
                                },
                                selectedColor: Colors.blue[100],
                                checkmarkColor: Colors.blue[700],
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
          // Results Count
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey[100],
            child: Text(
              '${_filteredCustomers.length} customers found',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
          // Customers List
          Expanded(
            child: _filteredCustomers.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredCustomers.length,
                    itemBuilder: (context, index) {
                      final customer = _filteredCustomers[index];
                      return _buildCustomerCard(customer);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No customers found',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search or filters',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerCard(Customer customer) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // Navigate to customer details
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('View ${customer.name} details')),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.grey[200],
                child: Text(
                  customer.name.split(' ').map((n) => n[0]).join().toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Customer Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            customer.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(customer.status).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            customer.status,
                            style: TextStyle(
                              color: _getStatusColor(customer.status),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      customer.company,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      customer.email,
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.attach_money, size: 16, color: Colors.green[600]),
                        Text(
                          '\$${customer.totalSpent.toStringAsFixed(0)}',
                          style: TextStyle(
                            color: Colors.green[600],
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(Icons.access_time, size: 16, color: Colors.grey[500]),
                        Text(
                          '${DateTime.now().difference(customer.lastOrder).inDays}d ago',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Action Button
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: Colors.grey[600]),
                onSelected: (value) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$value ${customer.name}')),
                  );
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'View', child: Text('View Details')),
                  const PopupMenuItem(value: 'Edit', child: Text('Edit Customer')),
                  const PopupMenuItem(value: 'Delete', child: Text('Delete Customer')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}