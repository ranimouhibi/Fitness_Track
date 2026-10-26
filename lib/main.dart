import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'app.dart';
import 'core/database/database_helper.dart';
import 'features/coaching/data/coach_booking_repository.dart';
import 'core/media/media_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    if (kIsWeb) {
      await DatabaseHelper.instance.initializeWeb(databaseFactoryFfiWeb);
    }
    await loadBundledImages();
    await DatabaseHelper.instance.database;
    await CoachBookingRepository().closePastBookings();
    runApp(const ProviderScope(child: FitTrackApp()));
  } catch (e, st) {
    debugPrint('STARTUP ERROR: $e\n$st');
    runApp(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Text('Startup error:\n\n$e',
                style: const TextStyle(color: Colors.red)),
          ),
        ),
      ),
    ));
  }
}
