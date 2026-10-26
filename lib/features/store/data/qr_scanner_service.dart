import 'package:mobile_scanner/mobile_scanner.dart';

/// Service pour gérer le scanning de QR codes et barcodes
class QRScannerService {
  static MobileScannerController createController({
    DetectionSpeed detectionSpeed = DetectionSpeed.normal,
    CameraFacing facing = CameraFacing.back,
    List<BarcodeFormat> formats = const [
      BarcodeFormat.qrCode,
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.code128,
    ],
  }) {
    return MobileScannerController(
      detectionSpeed: detectionSpeed,
      facing: facing,
      formats: formats,
    );
  }

  /// Parse un QR code de commande
  /// Format attendu: "ORDER:{orderId}"
  static int? parseOrderQRCode(String rawValue) {
    if (rawValue.startsWith('ORDER:')) {
      final orderIdStr = rawValue.substring(6);
      return int.tryParse(orderIdStr);
    }
    return null;
  }

  /// Parse un barcode de produit
  /// Format: code-barres direct ou "PRODUCT:{barcode}"
  static String? parseProductBarcode(String rawValue) {
    if (rawValue.startsWith('PRODUCT:')) {
      return rawValue.substring(8);
    }
    // Retourne le code-barres tel quel
    return rawValue;
  }

  /// Génère le contenu d'un QR code pour une commande
  static String generateOrderQRContent(int orderId) {
    return 'ORDER:$orderId';
  }

  /// Génère le contenu d'un QR code pour un produit
  static String generateProductQRContent(int productId, String? barcode) {
    if (barcode != null && barcode.isNotEmpty) {
      return 'PRODUCT:$barcode';
    }
    return 'PRODUCT_ID:$productId';
  }
}
