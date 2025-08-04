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
