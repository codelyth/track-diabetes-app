import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'features/home/data/home_widget_service.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  try {
    await HomeWidgetService.instance.initialize();
  } catch (error, stackTrace) {
    debugPrint('Widget servisi başlatılamadı: $error');
    debugPrintStack(stackTrace: stackTrace);
  }

  runApp(const DiabetesApp());
}
