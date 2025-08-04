//Customers data model
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


//Chat data model
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