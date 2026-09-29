import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../data/card_repository.dart';
import '../data/collection_repository.dart';
import '../utils/ocr_utils.dart';
import 'scan_confirm_screen.dart';

/// Scanner OCR do código da carta.
///
/// A câmera só fica ligada quando a aba está ativa e o app está em primeiro
/// plano. Um código só abre a confirmação depois de aparecer em [_hitsNeeded]
/// quadros seguidos, o que filtra leituras erradas de um único frame.
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({
    super.key,
    required this.cards,
    required this.collections,
    this.isActive = true,
  });
  final CardRepository cards;
  final CollectionRepository collections;
  final bool isActive;

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> with WidgetsBindingObserver {
  static const _minFrameGap = Duration(milliseconds: 250);
  static const _hitsNeeded = 2;
  static const _navCooldown = Duration(seconds: 2);

  final _recognizer = TextRecognizer();
  CameraController? _camera;
  bool _appResumed = true;
  bool _starting = false;
  bool _processing = false;
  bool _navigating = false;
  bool _torchOn = false;
  String? _error;

  String? _candidate;
  int _hits = 0;
  DateTime _lastFrame = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime? _lastNav;

  bool get _wantCamera => widget.isActive && _appResumed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_wantCamera) _startCamera();
  }

  @override
  void didUpdateWidget(ScannerScreen old) {
    super.didUpdateWidget(old);
    if (widget.isActive != old.isActive) _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appResumed = state == AppLifecycleState.resumed;
    _sync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final cam = _camera;
    _camera = null;
    if (cam != null) {
      () async {
        try {
          if (cam.value.isStreamingImages) await cam.stopImageStream();
        } catch (_) {}
        await cam.dispose();
      }();
    }
    _recognizer.close();
    super.dispose();
  }

  void _sync() {
    if (_wantCamera) {
      if (_camera == null) {
        _startCamera();
      } else if (!_navigating) {
        _startStream();
      }
    } else {
      _releaseCamera();
    }
  }

  // ---------- câmera ----------

  Future<void> _startCamera() async {
    if (_camera != null || _starting) return;
    _starting = true;
    if (mounted) setState(() => _error = null);
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) {
        if (mounted) setState(() => _error = 'Nenhuma câmera encontrada.');
        return;
      }
      final back = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cams.first,
      );
      final controller = CameraController(
        back,
        ResolutionPreset.high, // texto pequeno da carta pede mais que 480p
        enableAudio: false,
        imageFormatGroup:
            Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
      );
      await controller.initialize();
      if (!mounted || !_wantCamera) {
        await controller.dispose();
        return;
      }
      setState(() => _camera = controller);
      if (!_navigating) await _startStream();
    } on CameraException catch (e) {
      final denied = e.code.startsWith('CameraAccessDenied') ||
          e.code == 'CameraAccessRestricted';
      if (mounted) {
        setState(() => _error = denied
            ? 'Sem permissão para usar a câmera. Ative nas configurações do aparelho.'
            : 'Erro ao iniciar a câmera (${e.code}).');
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Erro ao iniciar a câmera.');
    } finally {
      _starting = false;
    }
  }

  Future<void> _releaseCamera() async {
    final cam = _camera;
    if (cam == null) return;
    setState(() {
      _camera = null;
      _torchOn = false;
    });
    _candidate = null;
    _hits = 0;
    await WidgetsBinding.instance.endOfFrame; // tira o preview da árvore antes
    try {
      if (cam.value.isStreamingImages) await cam.stopImageStream();
    } catch (_) {}
    await cam.dispose();
  }

  Future<void> _startStream() async {
    final cam = _camera;
    if (cam == null || !cam.value.isInitialized || cam.value.isStreamingImages) return;
    try {
      await cam.startImageStream(_onFrame);
    } catch (_) {}
  }

  Future<void> _stopStream() async {
    final cam = _camera;
    if (cam == null) return;
    try {
      if (cam.value.isStreamingImages) await cam.stopImageStream();
    } catch (_) {}
  }

  Future<void> _toggleTorch() async {
    final cam = _camera;
    if (cam == null || !cam.value.isInitialized) return;
    try {
      final next = !_torchOn;
      await cam.setFlashMode(next ? FlashMode.torch : FlashMode.off);
      if (mounted) setState(() => _torchOn = next);
    } catch (_) {
      if (mounted) setState(() => _torchOn = false);
    }
  }

  // ---------- reconhecimento ----------

  InputImage? _toInputImage(CameraImage image) {
    final cam = _camera;
    if (cam == null) return null;
    final rotation = InputImageRotationValue.fromRawValue(cam.description.sensorOrientation);
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (rotation == null || format == null) return null;
    if (Platform.isAndroid && format != InputImageFormat.nv21) return null;
    if (Platform.isIOS && format != InputImageFormat.bgra8888) return null;
    if (image.planes.length != 1) return null;
    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  Future<void> _onFrame(CameraImage image) async {
    if (_processing || _navigating || !mounted) return;
    final now = DateTime.now();
    if (now.difference(_lastFrame) < _minFrameGap) return;
    final lastNav = _lastNav;
    if (lastNav != null && now.difference(lastNav) < _navCooldown) return;
    _lastFrame = now;
    _processing = true;
    try {
      final input = _toInputImage(image);
      if (input == null) return;
      final result = await _recognizer.processImage(input);
      if (!mounted || _navigating) return;

      final codes = CardCodeExtractor.extractCodes(result.text);
      if (codes.isEmpty) {
        _candidate = null;
        _hits = 0;
        return;
      }
      final code = codes.first;
      if (code == _candidate) {
        _hits++;
      } else {
        _candidate = code;
        _hits = 1;
      }
      if (_hits >= _hitsNeeded) {
        _candidate = null;
        _hits = 0;
        await _goConfirm(code, codes.where((c) => c != code).toList());
      }
    } catch (_) {
      // Um frame ruim não deve derrubar o scanner.
    } finally {
      _processing = false;
    }
  }

  Future<void> _goConfirm(String code, List<String> alternatives) async {
    if (_navigating || !mounted) return;
    _navigating = true;
    await _stopStream();
    if (!mounted) return;

    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ScanConfirmScreen(
        repo: widget.cards,
        collections: widget.collections,
        detectedCode: code,
        alternativeCodes: alternatives.isEmpty ? null : alternatives,
      ),
    ));

    _navigating = false;
    _lastNav = DateTime.now();
    if (!mounted) return;
    _sync(); // reinicia o stream, ou a câmera inteira se o app foi pausado
  }

  /// Fallback manual: tira uma foto e lê o código.
  Future<void> _capture() async {
    final cam = _camera;
    if (cam == null || !cam.value.isInitialized || _processing || _navigating) return;
    setState(() => _processing = true);
    String? path;
    try {
      await _stopStream();
      final file = await cam.takePicture();
      path = file.path;
      final result = await _recognizer.processImage(InputImage.fromFilePath(path));
      final codes = CardCodeExtractor.extractCodes(result.text);
      if (!mounted) return;
      if (codes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Nenhum código encontrado. Aproxime a câmera e deixe o código legível.'),
        ));
        await _startStream();
      } else {
        setState(() => _processing = false);
        await _goConfirm(codes.first, codes.skip(1).toList());
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Não foi possível ler a foto.')));
        await _startStream();
      }
    } finally {
      if (path != null) {
        try {
          File(path).deleteSync();
        } catch (_) {}
      }
      if (mounted) setState(() => _processing = false);
    }
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scanner'),
        actions: [
          if (_camera != null)
            IconButton(
              tooltip: 'Lanterna',
              icon: Icon(_torchOn ? Icons.flash_on : Icons.flash_off),
              onPressed: _toggleTorch,
            ),
        ],
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.no_photography_outlined, size: 64),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: _startCamera, child: const Text('Tentar de novo')),
          ]),
        ),
      );
    }
    final cam = _camera;
    if (!widget.isActive) return const SizedBox.shrink();
    if (cam == null || !cam.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return Stack(fit: StackFit.expand, children: [
      Center(child: CameraPreview(cam)),
      const IgnorePointer(child: _CardGuide()),
      if (_processing)
        const Positioned(
          top: 16,
          left: 0,
          right: 0,
          child: Center(
            child: Chip(
              avatar: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              label: Text('Lendo...'),
            ),
          ),
        ),
      Positioned(
        bottom: 0,
        left: 0,
        right: 0,
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black.withAlpha(180)],
            ),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text(
              'Enquadre a carta com o código (ex.: BT1-010) legível e parado.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, shadows: [Shadow(blurRadius: 4)]),
            ),
            const SizedBox(height: 16),
            FloatingActionButton.large(
              heroTag: 'capture',
              tooltip: 'Tirar foto e ler',
              onPressed: _processing ? null : _capture,
              child: const Icon(Icons.camera_alt, size: 36),
            ),
          ]),
        ),
      ),
    ]);
  }
}

/// Moldura no formato de uma carta. É só uma referência visual: o OCR lê o
/// quadro inteiro, então o código pode estar em qualquer lugar da imagem.
class _CardGuide extends StatelessWidget {
  const _CardGuide();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Center(
      child: FractionallySizedBox(
        widthFactor: 0.72,
        child: AspectRatio(
          aspectRatio: 63 / 88,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: color.withAlpha(200), width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }
}
