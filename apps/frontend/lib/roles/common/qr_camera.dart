import 'package:eco_ui/eco_ui.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Live QR scanner in a rounded frame. Calls [onCode] with each new code it reads.
class QrCamera extends StatefulWidget {
  const QrCamera({super.key, required this.onCode, this.hint = '', this.height = 260});
  final void Function(String code) onCode;
  final String hint;
  final double height;

  @override
  State<QrCamera> createState() => _QrCameraState();
}

class _QrCameraState extends State<QrCamera> {
  final _controller = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  String? _last;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.eco;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        height: widget.height,
        child: Stack(alignment: Alignment.center, children: [
          Positioned.fill(
            child: MobileScanner(
              controller: _controller,
              onDetect: (capture) {
                final v = capture.barcodes.firstOrNull?.rawValue;
                if (v == null || v == _last) return;
                _last = v;
                widget.onCode(v);
              },
              errorBuilder: (context, error) => ColoredBox(color: c.ink, child: const Center(child: Icon(Icons.no_photography_rounded, color: Colors.white54, size: 40))),
            ),
          ),
          Container(
            width: 170,
            height: 170,
            decoration: BoxDecoration(border: Border.all(color: EcoColors.bloom, width: 3), borderRadius: BorderRadius.circular(24)),
          ),
          if (widget.hint.isNotEmpty) Positioned(bottom: 14, child: Text(widget.hint, style: const TextStyle(color: Colors.white))),
        ]),
      ),
    );
  }
}
