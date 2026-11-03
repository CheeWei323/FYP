import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fyp/screens/forgot_password_screen.dart';
import 'package:fyp/theme/app_theme.dart';

Future<void> openRecovery(
  WidgetTester tester, {
  required Future<void> Function(String email) sender,
  String initialEmail = '',
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: ForgotPasswordScreen(
        initialEmail: initialEmail,
        sendResetEmail: sender,
      ),
    ),
  );
}

Future<void> submitRecovery(WidgetTester tester) async {
  await tester.ensureVisible(find.byType(FilledButton));
  await tester.tap(find.byType(FilledButton));
  await tester.pump();
}

Future<void> closeRecovery(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
}

void main() {
  testWidgets('Invalid input makes no reset request', (tester) async {
    var requests = 0;
    await openRecovery(tester, sender: (_) async => requests++);

    await submitRecovery(tester);
    expect(find.text('Please enter your email.'), findsOneWidget);

    for (final email in ['missing-at', 'person@', 'person @example.com']) {
      await tester.enterText(find.byType(TextFormField), email);
      await submitRecovery(tester);
      expect(find.text('Please enter a valid email address.'), findsOneWidget);
    }
    expect(requests, 0);
    await closeRecovery(tester);
  });

  testWidgets('Email is prefilled, trimmed and submitted without a password', (
    tester,
  ) async {
    final emails = <String>[];
    await openRecovery(
      tester,
      initialEmail: '  traveller+recovery@example.com  ',
      sender: (email) async => emails.add(email),
    );
    expect(find.text('traveller+recovery@example.com'), findsOneWidget);

    await tester.enterText(
      find.byType(TextFormField),
      '  traveller+recovery@example.com  ',
    );
    await submitRecovery(tester);
    expect(emails, ['traveller+recovery@example.com']);
    expect(find.text('Check your inbox'), findsOneWidget);
    expect(find.textContaining('If this email is registered'), findsOneWidget);
    expect(find.text('Resend in 60s'), findsOneWidget);
    await closeRecovery(tester);
  });

  testWidgets('Pending requests and the cooldown prevent duplicate sends', (
    tester,
  ) async {
    final pending = Completer<void>();
    var requests = 0;
    await openRecovery(
      tester,
      initialEmail: 'traveller@example.com',
      sender: (_) {
        requests++;
        return pending.future;
      },
    );

    // The second tap occurs before a rebuild, exercising the in-flight guard.
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.tap(find.byType(FilledButton));
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(requests, 1);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );

    pending.complete();
    await tester.pump();
    await tester.pump();
    expect(find.text('Resend in 60s'), findsOneWidget);
    await tester.tap(find.byType(FilledButton));
    expect(requests, 1);

    await tester.pump(const Duration(seconds: 59));
    expect(find.text('Resend in 1s'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Resend reset email'), findsOneWidget);
    await submitRecovery(tester);
    expect(requests, 2);
    await closeRecovery(tester);
  });

  testWidgets('Unknown accounts receive the same neutral confirmation', (
    tester,
  ) async {
    await openRecovery(
      tester,
      initialEmail: 'unknown@example.com',
      sender: (_) async => throw FirebaseAuthException(code: 'user-not-found'),
    );
    await submitRecovery(tester);
    expect(find.text('Check your inbox'), findsOneWidget);
    expect(find.textContaining('If this email is registered'), findsOneWidget);
    expect(find.text('Resend in 60s'), findsOneWidget);
    expect(find.textContaining('No account'), findsNothing);
    await closeRecovery(tester);
  });

  testWidgets('Network failure permits retry without claiming email delivery', (
    tester,
  ) async {
    var requests = 0;
    await openRecovery(
      tester,
      initialEmail: 'traveller@example.com',
      sender: (_) async {
        requests++;
        if (requests == 1) {
          throw FirebaseAuthException(code: 'network-request-failed');
        }
      },
    );
    await submitRecovery(tester);
    expect(
      find.text('Check your internet connection and try again.'),
      findsOneWidget,
    );
    expect(find.text('Check your inbox'), findsNothing);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    await submitRecovery(tester);
    expect(requests, 2);
    expect(find.text('Check your inbox'), findsOneWidget);
    await closeRecovery(tester);
  });

  testWidgets('Firebase throttling displays a waiting message and cooldown', (
    tester,
  ) async {
    await openRecovery(
      tester,
      initialEmail: 'traveller@example.com',
      sender: (_) async =>
          throw FirebaseAuthException(code: 'too-many-requests'),
    );
    await submitRecovery(tester);
    expect(
      find.text('Too many requests. Please wait before trying again.'),
      findsOneWidget,
    );
    expect(find.text('Check your inbox'), findsNothing);
    expect(find.text('Resend in 60s'), findsOneWidget);
    await closeRecovery(tester);
  });

  testWidgets('Unexpected failures expose no raw Firebase exception message', (
    tester,
  ) async {
    await openRecovery(
      tester,
      initialEmail: 'traveller@example.com',
      sender: (_) async => throw FirebaseAuthException(
        code: 'internal-error',
        message: 'Internal provider details',
      ),
    );
    await submitRecovery(tester);
    expect(
      find.text('Unable to request a reset email. Please try again later.'),
      findsOneWidget,
    );
    expect(find.textContaining('Internal provider details'), findsNothing);
    expect(find.text('Check your inbox'), findsNothing);
    await closeRecovery(tester);
  });

  testWidgets('A late request completion is safe after leaving the screen', (
    tester,
  ) async {
    final pending = Completer<void>();
    await openRecovery(
      tester,
      initialEmail: 'traveller@example.com',
      sender: (_) => pending.future,
    );
    await submitRecovery(tester);
    await closeRecovery(tester);
    pending.complete();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Keyboard submission uses the same request flow', (tester) async {
    final emails = <String>[];
    await openRecovery(tester, sender: (email) async => emails.add(email));
    await tester.enterText(find.byType(TextFormField), 'traveller@example.com');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(emails, ['traveller@example.com']);
    expect(find.text('Check your inbox'), findsOneWidget);
    await closeRecovery(tester);
  });

  testWidgets(
    'Recovery remains scrollable on a narrow screen with larger text',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await openRecovery(
        tester,
        initialEmail: 'traveller@example.com',
        textScale: 1.5,
        sender: (_) async {},
      );
      await submitRecovery(tester);
      await tester.ensureVisible(find.text('Back to Login'));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Check your inbox'), findsOneWidget);
      await closeRecovery(tester);
    },
  );
}
