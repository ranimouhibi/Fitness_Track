import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/database/database_helper.dart';
import 'core/media/media_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await loadBundledImages();
    await DatabaseHelper.instance.database;
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