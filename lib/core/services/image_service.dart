import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ImageService {
  static final ImageService instance = ImageService._();
  ImageService._();

  final _picker = ImagePicker();

  /// Picks images and returns paths (file paths on mobile, base64 on web)
  Future<List<String>> pickImages({int limit = 3}) async {
    final images = await _picker.pickMultiImage(limit: limit);
    if (images.isEmpty) return [];

    if (kIsWeb) {
      // On web, convert to base64
      final base64Images = <String>[];
      for (final image in images) {
        final bytes = await image.readAsBytes();
        final base64 = base64Encode(bytes);
        // Store as data URL for consistency
        base64Images.add('data:image/${_getExtension(image.name)};base64,$base64');
      }
      return base64Images;
    } else {
      // On mobile, save to local storage
      final directory = await getApplicationDocumentsDirectory();
      final imageDirectory = Directory(p.join(directory.path, 'store_images'));
      await imageDirectory.create(recursive: true);
      
      final paths = <String>[];
      for (final image in images) {
        final destination = p.join(
          imageDirectory.path,
          '${DateTime.now().microsecondsSinceEpoch}_${p.basename(image.path)}',
        );
        paths.add((await File(image.path).copy(destination)).path);
      }
      return paths;
    }
  }

  /// Check if path is base64 data URL
  bool isBase64(String path) {
    return path.startsWith('data:image/');
  }

  /// Get extension from filename
  String _getExtension(String filename) {
    final ext = p.extension(filename).toLowerCase();
    switch (ext) {
      case '.jpg':
      case '.jpeg':
        return 'jpeg';
      case '.png':
        return 'png';
      case '.gif':
        return 'gif';
      case '.webp':
        return 'webp';
      default:
        return 'jpeg';
    }
  }
}
