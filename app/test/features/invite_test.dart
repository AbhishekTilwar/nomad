import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nomad_mingle/core/config/app_config.dart';
import 'package:nomad_mingle/core/theme/app_theme.dart';
import 'package:nomad_mingle/features/invite/invite_service.dart';
import 'package:nomad_mingle/features/invite/presentation/invite_contacts_screen.dart';
import 'package:nomad_mingle/features/invite/presentation/invite_screen.dart';

class FakeLauncher implements InviteLauncher {
  final calls = <String>[];
  bool ok = true;

  @override
  Future<bool> whatsapp(String text) async {
    calls.add('whatsapp:$text');
    return ok;
  }

  @override
  Future<bool> sms(String phone, String text) async {
    calls.add('sms:$phone');
    return ok;
  }

  @override
  Future<void> share(String text) async => calls.add('share:$text');

  @override
  Future<void> copy(String text) async => calls.add('copy:$text');
}

class FakeContacts implements ContactsSource {
  FakeContacts({this.access = ContactsAccess.granted});
  ContactsAccess access;
  int settingsOpened = 0;

  @override
  Future<ContactsAccess> requestAccess() async => access;

  @override
  Future<List<InviteContact>> load() async => const [
    InviteContact(name: 'Asha Rao', phone: '+91 98200 11111'),
    InviteContact(name: 'Vikram', phone: '+91 98200 22222'),
  ];

  @override
  Future<void> openSettings() async => settingsOpened++;
}

Widget app(Widget home) => MaterialApp(theme: AppTheme.light, home: home);

void main() {
  testWidgets('invite message carries the invite link', (t) async {
    expect(inviteMessage(), contains(AppConfig.inviteUrl));
    expect(inviteMessage(), contains('Nomad Mingle'));
  });

  testWidgets('WhatsApp, share and copy hand the invite to the launcher', (
    t,
  ) async {
    final l = FakeLauncher();
    await t.pumpWidget(app(InviteScreen(launcher: l)));
    await t.tap(find.byKey(const ValueKey('invite-whatsapp')));
    await t.tap(find.byKey(const ValueKey('invite-share')));
    await t.tap(find.byKey(const ValueKey('invite-copy')));
    await t.pump();
    expect(l.calls[0], 'whatsapp:${inviteMessage()}');
    expect(l.calls[1], 'share:${inviteMessage()}');
    expect(l.calls[2], 'copy:${AppConfig.inviteUrl}');
    expect(find.text('Link copied'), findsOneWidget);
  });

  testWidgets('a failed WhatsApp launch explains and offers another way', (
    t,
  ) async {
    final l = FakeLauncher()..ok = false;
    await t.pumpWidget(app(InviteScreen(launcher: l)));
    await t.tap(find.byKey(const ValueKey('invite-whatsapp')));
    await t.pump();
    expect(find.textContaining('Couldn\'t open WhatsApp'), findsOneWidget);
  });

  testWidgets('"Invite from contacts" opens the contacts route', (t) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => InviteScreen(launcher: FakeLauncher()),
        ),
        GoRoute(
          path: '/invite/contacts',
          builder: (_, _) => const Scaffold(body: Text('contacts screen')),
        ),
      ],
    );
    await t.pumpWidget(
      MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    );
    await t.tap(find.byKey(const ValueKey('invite-contacts')));
    await t.pumpAndSettle();
    expect(find.text('contacts screen'), findsOneWidget);
  });

  testWidgets('contacts: explain, allow, search, then invite by SMS', (
    t,
  ) async {
    final l = FakeLauncher();
    await t.pumpWidget(
      app(InviteContactsScreen(source: FakeContacts(), launcher: l)),
    );
    expect(find.textContaining('never uploaded'), findsOneWidget);
    await t.tap(find.text('Allow contacts access'));
    await t.pumpAndSettle();
    expect(find.text('Asha Rao'), findsOneWidget);
    expect(find.text('Vikram'), findsOneWidget);

    await t.enterText(find.byType(TextField), 'vik');
    await t.pump();
    expect(find.text('Asha Rao'), findsNothing);

    await t.tap(find.byKey(const ValueKey('invite-+91 98200 22222')));
    await t.pump();
    expect(l.calls.single, 'sms:+91 98200 22222');
    expect(find.text('Invited'), findsOneWidget);
  });

  testWidgets('contacts: denied and permanently denied states', (t) async {
    final src = FakeContacts(access: ContactsAccess.denied);
    await t.pumpWidget(
      app(InviteContactsScreen(source: src, launcher: FakeLauncher())),
    );
    await t.tap(find.text('Allow contacts access'));
    await t.pumpAndSettle();
    expect(find.text('Contacts access is off'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);

    src.access = ContactsAccess.permanentlyDenied;
    await t.tap(find.text('Try again'));
    await t.pumpAndSettle();
    await t.tap(find.text('Open settings'));
    expect(src.settingsOpened, 1);
  });

  testWidgets('device launcher copies text to the clipboard', (t) async {
    final copied = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        });
    await const DeviceInviteLauncher().copy('hello');
    expect(copied, ['hello']);
  });
}
