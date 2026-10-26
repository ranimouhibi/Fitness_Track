import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/app_colors.dart';
import '../data/qr_scanner_service.dart';
import '../data/store_repository.dart';

enum ScanMode { product, order }

class QRScannerPage extends ConsumerStatefulWidget {
  final String basePath;
  final ScanMode mode;

  const QRScannerPage({
    super.key,
    required this.basePath,
    this.mode = ScanMode.product,
  });

  @override
  ConsumerState<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends ConsumerState<QRScannerPage> {
  late MobileScannerController _controller;
  bool _isProcessing = false;
  final _repository = StoreRepository();

  @override
  void initState() {
    super.initState();
    _controller = QRScannerService.createController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleBarcode(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    setState(() => _isProcessing = true);

    try {
      final rawValue = barcode.rawValue!;

      if (widget.mode == ScanMode.order) {
        await _handleOrderScan(rawValue);
      } else {
        await _handleProductScan(rawValue);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _handleOrderScan(String rawValue) async {
    final orderId = QRScannerService.parseOrderQRCode(rawValue);
    
    if (orderId == null) {
      _showError('QR code invalide pour une commande');
      return;
    }

    // Vérifier que la commande existe
    try {
      final order = await _repository.orderById(orderId);
      if (order == null) {
        _showError('Commande #$orderId introuvable');
        return;
      }

      // Navigation vers les détails de la commande
      if (mounted) {
        _controller.stop();
        context.go('${widget.basePath}/orders/$orderId');
      }
    } catch (e) {
      _showError('Erreur lors de la récupération de la commande');
    }
  }

  Future<void> _handleProductScan(String rawValue) async {
    final barcode = QRScannerService.parseProductBarcode(rawValue);
    
    if (barcode == null) {
      _showError('Code-barres invalide');
      return;
    }

    // Rechercher le produit par barcode
    try {
      final products = await _repository.publicProducts(searchTerm: barcode);
      
      if (products.isEmpty) {
        _showError('Aucun produit trouvé avec ce code-barres');
        return;
      }

      // Si un seul produit, aller directement à ses détails
      if (products.length == 1) {
        if (mounted) {
          _controller.stop();
          context.push('${widget.basePath}/product/${products.first.id}');
        }
      } else {
        // Plusieurs produits, retourner à la liste avec recherche
        if (mounted) {
          _controller.stop();
          context.pop(barcode);
        }
      }
    } catch (e) {
      _showError('Erreur lors de la recherche');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.deepBlue],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Row(
          children: [
            const Icon(Icons.qr_code_scanner, color: Colors.white),
            const SizedBox(width: 8),
            Text(widget.mode == ScanMode.order 
              ? 'Scanner Commande' 
              : 'Scanner Produit'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_off, color: Colors.white),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch, color: Colors.white),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Scanner view
          MobileScanner(
            controller: _controller,
            onDetect: _handleBarcode,
          ),
          
          // Overlay avec zone de scan
          CustomPaint(
            painter: _ScannerOverlay(),
            child: const SizedBox.expand(),
          ),
          
          // Instructions
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(
                    widget.mode == ScanMode.order 
                      ? Icons.qr_code_2 
                      : Icons.barcode_reader,
                    color: Colors.white,
                    size: 40,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.mode == ScanMode.order
                      ? 'Scannez le QR code de la commande'
                      : 'Scannez le code-barres du produit',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Centrez le code dans le cadre',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          
          // Loading indicator
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

class _ScannerOverlay extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    final scanAreaSize = size.width * 0.7;
    final left = (size.width - scanAreaSize) / 2;
    final top = (size.height - scanAreaSize) / 2;

    // Draw overlay with transparent square
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, scanAreaSize, scanAreaSize),
        const Radius.circular(12),
      ))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);

    // Draw corner borders
    final borderPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    final cornerLength = 30.0;

    // Top-left
    canvas.drawLine(
      Offset(left, top + cornerLength),
      Offset(left, top),
      borderPaint,
    );
    canvas.drawLine(
      Offset(left, top),
      Offset(left + cornerLength, top),
      borderPaint,
    );

    // Top-right
    canvas.drawLine(
      Offset(left + scanAreaSize - cornerLength, top),
      Offset(left + scanAreaSize, top),
      borderPaint,
    );
    canvas.drawLine(
      Offset(left + scanAreaSize, top),
      Offset(left + scanAreaSize, top + cornerLength),
      borderPaint,
    );

    // Bottom-left
    canvas.drawLine(
      Offset(left, top + scanAreaSize - cornerLength),
      Offset(left, top + scanAreaSize),
      borderPaint,
    );
    canvas.drawLine(
      Offset(left, top + scanAreaSize),
      Offset(left + cornerLength, top + scanAreaSize),
      borderPaint,
    );

    // Bottom-right
    canvas.drawLine(
      Offset(left + scanAreaSize - cornerLength, top + scanAreaSize),
      Offset(left + scanAreaSize, top + scanAreaSize),
      borderPaint,
    );
    canvas.drawLine(
      Offset(left + scanAreaSize, top + scanAreaSize - cornerLength),
      Offset(left + scanAreaSize, top + scanAreaSize),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
