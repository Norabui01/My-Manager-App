import 'package:at_onboarding_flutter/at_onboarding_flutter.dart';
import 'package:path_provider/path_provider.dart';

class AtPlatformConfig {
  static const String namespace = 'chatapp';
  static const String rootDomain = 'root.atsign.org';
  
  // Replace with your actual API key from atsign.dev
  static const String apiKey = 'YOUR_API_KEY_HERE';
  
  static Future<AtClientPreference> getClientPreference() async {
    final dir = await getApplicationSupportDirectory();
    
    return AtClientPreference()
      ..rootDomain = rootDomain
      ..namespace = namespace
      ..hiveStoragePath = '${dir.path}/storage/hive'
      ..commitLogPath = '${dir.path}/storage/commitLog'
      ..isLocalStoreRequired = true
      ..syncStrategy = SyncStrategy.immediate
      ..syncIntervalMins = 1;
  }
  
  static AtOnboardingConfig getOnboardingConfig() {
    return AtOnboardingConfig(
      atClientPreference: AtClientPreference()
        ..rootDomain = rootDomain
        ..namespace = namespace
        ..isLocalStoreRequired = true,
      appAPIKey: apiKey,
      rootEnvironment: RootEnvironment.Production,
      domain: rootDomain,
    );
  }
}

class MessageKeys {
  static const String messagePrefix = 'message';
  static const String conversationPrefix = 'conversation';
  static const String metadataPrefix = 'metadata';
  
  static String messageKey(int timestamp) => '$messagePrefix.$timestamp';
  static String conversationKey(String atSign) => '$conversationPrefix.${atSign.replaceAll('@', '')}';
  static String metadataKey(String type) => '$metadataPrefix.$type';
}

class AtPlatformHelper {
  static bool isValidAtSign(String atSign) {
    if (atSign.isEmpty) return false;
    
    // Remove @ if present for validation
    String cleanAtSign = atSign.startsWith('@') ? atSign.substring(1) : atSign;
    
    // Basic validation rules
    if (cleanAtSign.isEmpty) return false;
    if (cleanAtSign.length < 1 || cleanAtSign.length > 55) return false;
    
    // Should not contain invalid characters
    RegExp validPattern = RegExp(r'^[a-zA-Z0-9_.-]+$');
    return validPattern.hasMatch(cleanAtSign);
  }
  
  static String formatAtSign(String atSign) {
    if (atSign.isEmpty) return atSign;
    return atSign.startsWith('@') ? atSign : '@$atSign';
  }
  
  static String getDisplayName(String atSign) {
    return atSign.replaceAll('@', '');
  }
  
  static String getInitials(String atSign) {
    String displayName = getDisplayName(atSign);
    if (displayName.length >= 2) {
      return displayName.substring(0, 2).toUpperCase();
    }
    return displayName.toUpperCase();
  }
}

// Error handling for atPlatform operations
class AtPlatformException implements Exception {
  final String message;
  final String? code;
  final dynamic originalException;
  
  AtPlatformException(this.message, {this.code, this.originalException});
  
  @override
  String toString() {
    return 'AtPlatformException: $message${code != null ? ' (Code: $code)' : ''}';
  }
}

// Message status enum
enum MessageStatus {
  sending,
  sent,
  delivered,
  failed,
}

// Enhanced message model with status
class EnhancedChatMessage {
  String id;
  String text;
  bool isMe;
  DateTime timestamp;
  String senderAtSign;
  MessageStatus status;
  String? error;
  
  EnhancedChatMessage({
    required this.id,
    required this.text,
    required this.isMe,
    required this.timestamp,
    required this.senderAtSign,
    this.status = MessageStatus.sent,
    this.error,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'isMe': isMe,
      'timestamp': timestamp.toIso8601String(),
      'senderAtSign': senderAtSign,
      'status': status.toString(),
      'error': error,
    };
  }
  
  factory EnhancedChatMessage.fromJson(Map<String, dynamic> json) {
    return EnhancedChatMessage(
      id: json['id'] ?? '',
      text: json['text'] ?? '',
      isMe: json['isMe'] ?? false,
      timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
      senderAtSign: json['senderAtSign'] ?? '',
      status: MessageStatus.values.firstWhere(
        (e) => e.toString() == json['status'],
        orElse: () => MessageStatus.sent,
      ),
      error: json['error'],
    );
  }
}