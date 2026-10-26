import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../theme/app_colors.dart';

/// "Bench Press" -> "bench_press"
String slugOf(String name) => name
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
    .replaceAll(RegExp(r'^_+|_+$'), '');

/// Image types the app accepts.
const _imageExtensions = {'gif', 'png', 'jpg', 'jpeg', 'webp'};

/// Keeps only letters and digits, lowercased, so names match loosely.
String _normalize(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

/// Index of bundled images: "assets/programs|beginnermassfoundation" -> path.
final Map<String, String> _index = {};

/// Reads the list of bundled images. Call once in main(), before the database.
Future<void> loadBundledImages() async {
  final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
  _index.clear();
  for (final asset in manifest.listAssets()) {
    if (!asset.startsWith('assets/')) continue;
    final ext = p.extension(asset).replaceFirst('.', '').toLowerCase();
    if (!_imageExtensions.contains(ext)) continue;
    final folder = p.posix.dirname(asset);
    final base = p.posix.basenameWithoutExtension(asset);
    _index['$folder|${_normalize(base)}'] = asset;
  }
  debugPrint('Bundled images found: ${_index.length}');
}

/// Finds the bundled image for a name, whatever its type and spelling.
/// [folder] is e.g. 'assets/programs' and [base] is the name, e.g. 'Beginner Mass Foundation'.
/// Returns null if no matching file is bundled.
String? findBundledImage(String folder, String base) =>
    _index['$folder|${_normalize(base)}'];

/// Data-set media ships inside the app and starts with 'assets/'.
bool isBundledMedia(String? path) => path != null && path.startsWith('assets/');

/// Copies a photo picked by a user into the app's own folder.
Future<String> saveUserMedia(String source, String folder) async {
  final dir = await getApplicationDocumentsDirectory();
  final target = Directory(p.join(dir.path, folder));
  await target.create(recursive: true);
  final dest = p.join(
    target.path,
    '${DateTime.now().millisecondsSinceEpoch}${p.extension(source)}',
  );
  await File(source).copy(dest);
  return dest;
}

/// Deletes a user-added photo file. Data-set files are never deleted.
Future<void> deleteUserMedia(String? path) async {
  if (path == null || path.isEmpty || isBundledMedia(path)) return;
  final file = File(path);
  if (await file.exists()) await file.delete();
}

/// Shows a data-set asset or a user photo, with a placeholder if it is missing.
/// BoxFit.fill stretches the picture so it fills the whole holder with no cut-off.
Widget mediaImage(
  String? path, {
  BoxFit fit = BoxFit.fill,
  IconData placeholder = Icons.fitness_center,
}) {
  Widget fallback() => Container(
        color: AppColors.softBlue,
        alignment: Alignment.center,
        child: Icon(placeholder, color: AppColors.deepBlue),
      );

  if (path == null || path.isEmpty) return fallback();
  if (isBundledMedia(path)) {
    return Image.asset(
      path,
      fit: fit,
      errorBuilder: (_, __, ___) => fallback(),
    );
  }
  final file = File(path);
  return file.existsSync() ? Image.file(file, fit: fit) : fallback();
}