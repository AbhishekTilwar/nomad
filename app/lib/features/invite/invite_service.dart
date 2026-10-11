import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';

/// Text sent with every invitation (WhatsApp, SMS, share sheet).
String inviteMessage() =>
    'Join me on Nomad Mingle: find your people, make a plan, go together. '
    '${AppConfig.inviteUrl}';

/// A person from the device address book that can be texted.
class InviteContact {
  const InviteContact({required this.name, required this.phone});
  final String name;
  final String phone;
}

enum ContactsAccess { granted, denied, permanentlyDenied }

/// Reads the device address book. Contacts are used on-device only: nothing
/// here is sent to our servers.
abstract class ContactsSource {
  Future<ContactsAccess> requestAccess();
  Future<List<InviteContact>> load();
  Future<void> openSettings();
}

class DeviceContactsSource implements ContactsSource {
  const DeviceContactsSource();

  @override
  Future<ContactsAccess> requestAccess() async {
    final status = await FlutterContacts.permissions.request(
      PermissionType.read,
    );
    switch (status) {
      case PermissionStatus.granted:
      case PermissionStatus.limited:
        return ContactsAccess.granted;
      case PermissionStatus.permanentlyDenied:
      case PermissionStatus.restricted:
        return ContactsAccess.permanentlyDenied;
      case PermissionStatus.denied:
      case PermissionStatus.notDetermined:
        return ContactsAccess.denied;
    }
  }

  @override
  Future<List<InviteContact>> load() async {
    final all = await FlutterContacts.getAll(
      properties: {ContactProperty.phone},
    );
    final seen = <String>{};
    final out = <InviteContact>[];
    for (final c in all) {
      if (c.phones.isEmpty) continue;
      final number = c.phones.first.number.trim();
      final name = (c.displayName ?? '').trim();
      if (number.isEmpty || !seen.add(number.replaceAll(RegExp(r'\D'), ''))) {
        continue;
      }
      out.add(InviteContact(name: name.isEmpty ? number : name, phone: number));
    }
    out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return out;
  }

  @override
  Future<void> openSettings() => FlutterContacts.permissions.openSettings();
}

/// Hands an invitation to another app. Each method returns false when the
/// target app could not be opened.
abstract class InviteLauncher {
  Future<bool> whatsapp(String text);
  Future<bool> sms(String phone, String text);
  Future<void> share(String text);
  Future<void> copy(String text);
}

class DeviceInviteLauncher implements InviteLauncher {
  const DeviceInviteLauncher();

  @override
  Future<bool> whatsapp(String text) =>
      _open(Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}'));

  @override
  Future<bool> sms(String phone, String text) {
    final number = phone.replaceAll(RegExp(r'[^\d+]'), '');
    return _open(Uri.parse('sms:$number?body=${Uri.encodeComponent(text)}'));
  }

  @override
  Future<void> share(String text) async {
    await SharePlus.instance.share(
      ShareParams(subject: 'Join me on Nomad Mingle', text: text),
    );
  }

  @override
  Future<void> copy(String text) =>
      Clipboard.setData(ClipboardData(text: text));

  Future<bool> _open(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
