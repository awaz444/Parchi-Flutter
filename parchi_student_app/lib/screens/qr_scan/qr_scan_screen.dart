import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../utils/colours.dart';
import '../qr_redemption/qr_redemption_screen.dart';

class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isProcessing = false;
  bool _torchOn = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;
    for (final barcode in capture.barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue == null) continue;
      final branchId = _extractBranchId(rawValue);
      if (branchId != null) {
        _isProcessing = true;
        _controller.stop();
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => QrRedemptionScreen(branchId: branchId),
            ),
          );
        }
        return;
      }
    }
  }

  String? _extractBranchId(String rawValue) {
    try {
      final uri = Uri.parse(rawValue);
      // parchi://redeem/{branchId}
      if (uri.scheme == 'parchi' && uri.host == 'redeem') {
        return uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
      }
      // https://www.parchipakistan.com/redeem/{branchId}
      if ((uri.scheme == 'https' || uri.scheme == 'http') &&
          uri.pathSegments.contains('redeem')) {
        final idx = uri.pathSegments.indexOf('redeem');
        if (idx + 1 < uri.pathSegments.length) {
          return uri.pathSegments[idx + 1];
        }
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          CustomPaint(painter: _ScanOverlayPainter()),
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                const Spacer(),
                _buildReticleLabel(),
                const Spacer(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 28),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Expanded(
            child: Text(
              'Scan Parchi QR',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              _torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
              color: Colors.white,
              size: 28,
            ),
            onPressed: () {
              _controller.toggleTorch();
              setState(() => _torchOn = !_torchOn);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildReticleLabel() {
    return Column(
      children: [
        Container(
          width: 240,
          height: 240,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.transparent),
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Point at a Parchi QR code',
          style: TextStyle(color: Colors.white70, fontSize: 15),
        ),
        const SizedBox(height: 48),
      ],
    );
  }
}

class _ScanOverlayPainter extends CustomPainter {
  static const double _reticleSize = 240;
  static const double _cornerRadius = 16;
  static const double _cornerLength = 30;

  @override
  void paint(Canvas canvas, Size size) {
    final reticleRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: _reticleSize,
      height: _reticleSize,
    );

    // Dark overlay with transparent cutout
    final overlayPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(
          reticleRect, const Radius.circular(_cornerRadius)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(overlayPath, Paint()..color = Colors.black54);

    // Colored corner brackets
    final cornerPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final l = reticleRect.left;
    final t = reticleRect.top;
    final r = reticleRect.right;
    final b = reticleRect.bottom;
    const cr = _cornerRadius;

    // Top-left
    canvas.drawLine(Offset(l + cr, t), Offset(l + cr + _cornerLength, t), cornerPaint);
    canvas.drawLine(Offset(l, t + cr), Offset(l, t + cr + _cornerLength), cornerPaint);
    // Top-right
    canvas.drawLine(Offset(r - cr, t), Offset(r - cr - _cornerLength, t), cornerPaint);
    canvas.drawLine(Offset(r, t + cr), Offset(r, t + cr + _cornerLength), cornerPaint);
    // Bottom-left
    canvas.drawLine(Offset(l + cr, b), Offset(l + cr + _cornerLength, b), cornerPaint);
    canvas.drawLine(Offset(l, b - cr), Offset(l, b - cr - _cornerLength), cornerPaint);
    // Bottom-right
    canvas.drawLine(Offset(r - cr, b), Offset(r - cr - _cornerLength, b), cornerPaint);
    canvas.drawLine(Offset(r, b - cr), Offset(r, b - cr - _cornerLength), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
