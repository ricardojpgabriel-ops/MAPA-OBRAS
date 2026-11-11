import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../main.dart' show cameras;
import '../services/ocr_service.dart';
import 'theme.dart';

class ScanPage extends StatefulWidget {
  final String fallbackGame;
  final String? apiKey;
  const ScanPage({super.key, required this.fallbackGame, this.apiKey});
  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  CameraController? _cam;
  final _ocr = OcrService();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initCam();
  }

  Future<void> _initCam() async {
    if (cameras.isEmpty) {
      setState(() => _error = 'Nenhuma câmara disponível neste dispositivo.');
      return;
    }
    final back = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );
    final ctrl = CameraController(back, ResolutionPreset.high,
        enableAudio: false, imageFormatGroup: ImageFormatGroup.jpeg);
    try {
      await ctrl.initialize();
      if (!mounted) return;
      setState(() => _cam = ctrl);
    } catch (e) {
      setState(() => _error = 'Não foi possível aceder à câmara. Verifique as permissões.');
    }
  }

  Future<void> _capture() async {
    if (_cam == null || _busy) return;
    setState(() => _busy = true);
    try {
      final file = await _cam!.takePicture();
      final scan = await _ocr.scanImage(file.path, fallbackGame: widget.fallbackGame, apiKey: widget.apiKey);
      if (!mounted) return;
      Navigator.pop(context, scan);
    } catch (e) {
      setState(() {
        _busy = false;
        _error = 'Falha na leitura. Tente novamente com mais luz e o talão direito.';
      });
    }
  }

  @override
  void dispose() {
    _cam?.dispose();
    _ocr.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Digitalizar talão'),
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 15)),
              ),
            )
          : _cam == null
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    CameraPreview(_cam!),
                    // moldura de enquadramento
                    Center(
                      child: FractionallySizedBox(
                        widthFactor: 0.88,
                        heightFactor: 0.7,
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white70, width: 2),
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const Positioned(
                      top: 16,
                      left: 0,
                      right: 0,
                      child: Text('Enquadre o talão · boa luz · direito',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white, fontSize: 13)),
                    ),
                    if (_busy)
                      Container(
                        color: Colors.black54,
                        child: const Center(
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            CircularProgressIndicator(color: Colors.white),
                            SizedBox(height: 12),
                            Text('A ler o talão…', style: TextStyle(color: Colors.white)),
                          ]),
                        ),
                      ),
                    Positioned(
                      bottom: 30,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: GestureDetector(
                          onTap: _capture,
                          child: Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              border: Border.all(color: santaGreen, width: 5),
                            ),
                            child: const Icon(Icons.camera_alt, color: santaGreen, size: 32),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
