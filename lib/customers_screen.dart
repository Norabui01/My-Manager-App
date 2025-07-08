import 'package:at_utils/at_utils.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'onboarding_configuration.dart';
import 'package:at_client_mobile/at_client_mobile.dart';
//Screen UI
class CustomerScreen extends StatefulWidget {
  const CustomerScreen({super.key});

  @override
  State<CustomerScreen> createState() => _CustomerScreenState();
}

class _CustomerScreenState extends State<CustomerScreen> {
  AtNotification? notification;
  int _unreadNotifications = 0;
  final AtSignLogger _logger = AtSignLogger('CustomerScreen');

  List<Customer> customers = [];

  @override
  void initState() {
    super.initState();
    _setupNotificationListener();
  }

  //Load customer file from pick file
  Future<void> loadCustomerFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json', 'txt'],
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final content = await file.readAsString();
      final parsed = parseCustomerJson(content);

      setState(() {
        customers = parsed;
      });
    }
    
  }

  Future<void> _navigateToOnboarding() async {
  await OnboardingConfig.onboardUser(
    context: context,
    apiKey: dotenv.env['API_KEY'],
    namespace: dotenv.env['NAMESPACE_CUSTOMER'],
    onSuccess: (atSign) async {
      _logger.info('Customer onboarding success: $atSign');
      // Optionally retry sending if needed here
    },
    /*onError: (error) {
      _logger.severe('Customer onboarding failed: $error');
      _showSnackBar('Onboarding failed. Please try again.');
    },*/
  );
}


  //send customer file to another atsign
  Future<void> sendCustomers(String receiverAtSign) async {
    try {
    final atClient = AtClientManager.getInstance().atClient;
    final currentAtSign = atClient.getCurrentAtSign();

    if (currentAtSign == null) {
      await _navigateToOnboarding();
      return;
    }

    final jsonData = encodeCustomerJson(
      customers/*.map((c) {
        return Customer(
          id: c.id,
          name: c.name,
          phone: c.phone,
          location: c.location,
          bonusPoints: c.bonusPoints,
          giftCard: c.giftCard,
          services: c.services,
          senderAtSign: currentAtSign,
          receiverAtSign: receiverAtSign,
        );
      }).toList(),*/
    );

    final key = AtKey()
    ..key = 'customer_data'
    ..namespace = dotenv.env['NAMESPACE_CUSTOMER']
    ..sharedWith = receiverAtSign
    ..sharedBy = currentAtSign
    ..metadata = (Metadata()
      ..isEncrypted = true
      ..namespaceAware = true
      ..isPublic = false);

    //Store the customer data
    await atClient.put(key, jsonData);

    //Send notification
    await atClient.notificationService.notify(
      NotificationParams.forUpdate(
        key,
        value: jsonData,
      )
    );

    _showSnackBar('Customer data sent to $receiverAtSign');

    } catch (e) {
      _logger.severe('Error sending customer data: $e');
      _showSnackBar('Failed to send customer data');
    }

  }

  void _showSnackBar(String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Colors.blue,
    ),
  );
  }

  //Ask who you send to 
  Future<String?> _askReceiverAtSign() async {
    String? input;
    await showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Enter receiver @sign'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: '@receiver'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                input = controller.text.trim();
                Navigator.pop(context);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
    return input;
  }

  

  //set up notification when receive customer
  //set up notification listener (only stores the notification, doesn't auto-load)
  bool _isListenerSet = false; // Add this as a class variable

  void _setupNotificationListener() {
    if (_isListenerSet) return;
    _isListenerSet = true;

    final atClient = AtClientManager.getInstance().atClient;
    final currentAtSign = atClient.getCurrentAtSign();

    atClient.notificationService.subscribe().listen((incomingNotification) {
      final fromAtSign = incomingNotification.from;
      final key = incomingNotification.key.toLowerCase();

      _logger.info('Notification received from: $fromAtSign');
      _logger.info('Notification key: $key');

      // Skip self-notifications and unrelated keys
      if ((key.contains('customer_data') || key.contains('statsnotification')) &&
          fromAtSign != currentAtSign) {
        if (mounted) {
          setState(() {
            notification = incomingNotification;
          });
          _showSnackBar('New data received from $fromAtSign. Click download to load it.');
        }
      } else {
        _logger.info('Ignored notification: either from self or irrelevant.');
      }
  });
}


  //load and see the customers you received
  Future<void> loadCustomers() async {
    try {
      final atClient = AtClientManager.getInstance().atClient;
      final currentAtSign = atClient.getCurrentAtSign();

      if (currentAtSign == null) {
        await _navigateToOnboarding();
        return;
      }

      //final senderAtSign = await _askReceiverAtSign();
      final senderAtSign = notification?.from;

      final key = AtKey()
        ..key = 'customer_data'
        ..namespace = dotenv.env['NAMESPACE_CUSTOMER']
        ..sharedWith = currentAtSign
        ..sharedBy = senderAtSign
        ..metadata = (Metadata()
          ..isEncrypted = true
          ..namespaceAware = true
          ..isPublic = false);

      final atValue = await atClient.get(key);

      if (atValue.value != null) {
        final loadedCustomers = parseCustomerJson(atValue.value!);

        setState(() {
          customers = loadedCustomers;
        });

        _showSnackBar('Loaded ${loadedCustomers.length} customers');
      } else {
        _showSnackBar('No customers data found for $currentAtSign');
      }
    } catch (e) {
      _logger.severe('Error loading customer data: $e');
      _showSnackBar('Failed to load customer data');

    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: loadCustomerFile,
            tooltip: 'Load Customer File',
          ),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: () async {
              final receiverAtSign = await _askReceiverAtSign();
              if (receiverAtSign != null && receiverAtSign.isNotEmpty) {
                await sendCustomers(receiverAtSign);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Load Customers from Server',
            onPressed: loadCustomers,
          )
        ],
      ),
      body: customers.isEmpty
          ? const Center(child: Text('No customers loaded'))
          : ListView.builder(
              itemCount: customers.length,
              itemBuilder: (context, index) {
                final customer = customers[index];
                return Card(
                  margin: const EdgeInsets.all(8),
                  child: ExpansionTile(
                    title: Text('${customer.name} (${customer.phone})'),
                    subtitle: Text (
                      'Bonus: ${customer.bonusPoints ?? 0} | GiftCard: \$${customer.giftCard?.balance.toStringAsFixed(2) ?? '0.00'}'),
                    children: customer.services.map((s) {
                      return ListTile(
                        title: Text('${s.date} - ${s.serviceType}'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: s.workers.map((w) {
                            return Text('${w.role} by ${w.name}, Tip: \$${w.tip}');
                          }).toList(),
                        ),
                        trailing: Text('\$${s.price.toStringAsFixed(2)}'),
                      );
                    }).toList(),
                  ),
                );
              },
          ),
    );
  }
}

//Data model
class Customer {
  final String id;
  final String name;
  final String phone;
  final String? location;
  int? bonusPoints;
  GiftCard? giftCard;
  List<Service> services;

  String senderAtSign; //who sent data
  String receiverAtSign; //who is intended to receive

  Customer({
    required this.id,
    required this.name,
    required this.phone,
    this.location,
    this.bonusPoints,
    this.giftCard,
    required this.services,
    required this.senderAtSign,
    required this.receiverAtSign,
  });

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
    id: json['id'],
    name: json['name'],
    phone: json['phone'],
    location: json['location'],
    bonusPoints: json['bonusPoints'],
    giftCard: GiftCard.fromJson(json['giftCard']),
    services: (json['services'] as List)
              .map((s) => Service.fromJson(s))
              .toList(),

    senderAtSign: json['senderAtSign'] ?? '',
    receiverAtSign: json['receiverAtSign'] ?? '',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'location': location,
    'bonusPoints': bonusPoints,
    'giftCard': giftCard?.toJson(),
    'services': services.map((s) => s.toJson()).toList(),

    'senderAtSign': senderAtSign,
    'receiverAtSign': receiverAtSign,
  };
}

class GiftCard {
  String number;
  double balance;

  GiftCard({
    required this.number,
    required this.balance,
  });

  factory GiftCard.fromJson(Map<String, dynamic> json) => GiftCard(
    number: json['number'],
    balance: (json['balance'] as num).toDouble(),
  );

  Map<String, dynamic> toJson() => {
    'number': number,
    'balance': balance,
  };
}

class Service {
  String date;
  String serviceType;
  double price;
  List<WorkerTip> workers;

  Service({
    required this.date,
    required this.serviceType,
    required this.price,
    required this.workers,
  });

  factory Service.fromJson(Map<String, dynamic> json) => Service(
    date: json['date'],
    serviceType: json['serviceType'],
    price: (json['price'] as num).toDouble(),
    workers: (json['workers'] as List)
              .map((w) => WorkerTip.fromJson(w))
              .toList(),
  );

  Map<String, dynamic> toJson() => {
    'date': date,
    'serviceType': serviceType,
    'price': price,
    'workers': workers.map((w) => w.toJson()).toList(),
  };
}

class WorkerTip {
  String name;
  String role;
  double tip;

  WorkerTip({
    required this.name,
    required this.role,
    required this.tip,
  });

  factory WorkerTip.fromJson(Map<String, dynamic> json) => WorkerTip(
    name: json['name'],
    role: json['role'],
    tip: (json['tip'] as num).toDouble(),
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'role': role,
    'tip': tip,
  };
}

//Parse File
List<Customer> parseCustomerJson(String jsonString) {
  final data = jsonDecode(jsonString);
  final customers = data['customers'] as List;
  return customers.map((c) => Customer.fromJson(c)).toList();
}

String encodeCustomerJson(List<Customer> customers) {
  return jsonEncode({
    'customers': customers.map((c) => c.toJson()).toList(),
  });
}

