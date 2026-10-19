import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/database/database_helper.dart';
import 'features/coaching/data/coach_booking_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseHelper.instance.database;
  await CoachBookingRepository().closePastBookings();
  runApp(const ProviderScope(child: FitTrackApp()));
}