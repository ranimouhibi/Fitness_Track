import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'app.dart';
import 'core/database/database_helper.dart';
import 'features/coaching/data/coach_booking_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize database for web
  if (kIsWeb) {
    await DatabaseHelper.instance.initializeWeb(databaseFactoryFfiWeb);
  }
  
  await DatabaseHelper.instance.database;
  await CoachBookingRepository().closePastBookings();
  runApp(const ProviderScope(child: FitTrackApp()));
}