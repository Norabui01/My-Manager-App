import 'package:at_onboarding_flutter/at_onboarding_flutter.dart';
import 'package:flutter/material.dart';


class OnboardingConfig {
  static Future<String?> onboardUser({
    required BuildContext context,
    required String? apiKey,
    required String? namespace,
    required Future<void> Function(String atSign) onSuccess,
    Future<void> Function()? onFailure,
    String rootDomain = 'root.atsign.org',
    String hiveStoragePath = '/storage/hive',
    String commitLogPath = '/storage/comitLog',
  }) async {
    final config = AtOnboardingConfig(
      atClientPreference: AtClientPreference()
        ..rootDomain = rootDomain
        ..namespace = namespace
        ..hiveStoragePath = hiveStoragePath
        ..commitLogPath = commitLogPath
        ..isLocalStoreRequired = true,
      appAPIKey: apiKey,
      rootEnvironment: RootEnvironment.Production,
    );

    final result = await AtOnboarding.onboard(
      context: context,
      config: config,
    );

    if (result.status == AtOnboardingResultStatus.success) {
      final atSign = result.atsign!;
      await onSuccess(atSign);
      return atSign;
    } else {
      if (onFailure != null) await onFailure();
      return null;
    }
  }
}
/*class AtPlatformConfig {
  static const String namespace = 'chatapp';
  static const String rootDomain = 'root.atsign.org';

  static String apiKey = dotenv.env['API_KEY'] ?? 'YOUR_API_KEY';

  static Future<AtClientPreference> getClientPreference() async {
    final dir = await getApplicationSupportDirectory();

    return AtClientPreference()
      ..rootDomain = rootDomain
      ..namespace = namespace
      ..hiveStoragePath = '${dir.path}/storage/hive'
      ..commitLogPath = '${dir.path}/storage/commitLog'
      ..isLocalStoreRequired = true
      //..syncStrategy = SyncStrategy.immediate
      ..syncIntervalMins = 0
      ..fetchOfflineNotifications = true
      ..monitorHeartbeatInterval = Duration(seconds: 30);
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
    if (cleanAtSign.length > 55) return false;

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
}*/

// Message sync helper
class MessageSyncHelper {
  static Future<void> syncMessages(AtClient atClient, String currentAtSign) async {
    try {
      // Force sync with the server
      atClient.syncService.sync();

      // Get the monitor connection to check for any pending notifications
      //final notificationService = atClient.notificationService;

      // The notification service will automatically fetch notifications
      // when the monitor connection is active

    } catch (e) {
      print('Error syncing messages: $e');
    }
  }

  static Future<List<AtKey>> getMessageKeys(
      AtClient atClient,
      String otherAtSign,
      String currentAtSign,
      ) async {
    final List<AtKey> messageKeys = [];

    try {
      // Get all message keys
      final regex = 'message\\..*';

      // Get messages we sent
      final sentKeys = await atClient.getKeys(
        regex: regex,
        sharedWith: otherAtSign,
      );

      // Get messages we received
      final receivedKeys = await atClient.getKeys(
        regex: regex,
        sharedBy: otherAtSign,
      );

      // Process sent keys
      for (String key in sentKeys) {
        final atKey = AtKey.fromString(key);
        atKey.sharedBy = currentAtSign;
        atKey.sharedWith = otherAtSign;
        messageKeys.add(atKey);
      }

      // Process received keys
      for (String key in receivedKeys) {
        final atKey = AtKey.fromString(key);
        atKey.sharedBy = otherAtSign;
        atKey.sharedWith = currentAtSign;
        messageKeys.add(atKey);
      }

    } catch (e) {
      print('Error getting message keys: $e');
    }

    return messageKeys;
  }
}
/*
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
}*/