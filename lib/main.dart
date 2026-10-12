import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize local notification scheduling.
  // Permissions will be requested when a reminder is scheduled.
  try {
    await NotificationService.instance.initialize();
  } catch (error) {
    debugPrint('NOTIFICATION INITIALIZATION ERROR: $error');
  }

  runApp(const TravelGuardApp());
}
