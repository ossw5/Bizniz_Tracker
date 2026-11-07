import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final _barcodeController = TextEditingController();
  bool _completed = false;

  bool get _cameraSupported =>
      kIsWeb ||
      switch (defaultTargetPlatform) {
        TargetPlatform.android ||
        TargetPlatform.iOS ||
        TargetPlatform.macOS => true,
        TargetPlatform.fuchsia ||
        TargetPlatform.linux ||
        TargetPlatform.windows => false,
      };

  @override
  void dispose() {
    _barcodeController.dispose();
    super.dispose();
  }

  void _complete(String barcode) {
    final value = barcode.trim();
    if (_completed || value.isEmpty) return;
    _completed = true;
    Navigator.of(context).pop(value);
  }

  void _handleCapture(BarcodeCapture capture) {
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value != null && value.trim().isNotEmpty) {
        _complete(value);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Scan Barcode'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_cameraSupported) ...[
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: MobileScanner(
                    onDetect: _handleCapture,
                    errorBuilder: (context, error) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Camera unavailable: ${error.errorCode.name}. '
                          'Enter or scan a barcode below.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Align a registered product barcode in the camera.'),
            ] else ...[
              const Expanded(
                child: Center(
                  child: Text(
                    'Camera scanning is not available on this platform. '
                    'Enter or scan a barcode with a connected scanner below.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _barcodeController,
              autofocus: !_cameraSupported,
              decoration: InputDecoration(
                labelText: 'Enter barcode manually',
                prefixIcon: const Icon(Icons.qr_code_2_rounded),
                suffixIcon: IconButton(
                  tooltip: 'Add barcode',
                  onPressed: () => _complete(_barcodeController.text),
                  icon: const Icon(Icons.arrow_forward_rounded),
                ),
                border: const OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: _complete,
            ),
          ],
        ),
      ),
    );
  }
}
