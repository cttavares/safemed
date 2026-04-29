import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../models/medication_match.dart';
import '../services/medication_explorer_service.dart';
import '../services/ocr_service.dart';
import 'scanner/bounding_box_painter.dart';
import 'scanner/flutter_vision_isolate.dart';
import 'scanner/ocr_screen.dart';

enum _ExplorerMode { camera, manual }

const Color _cameraAccent = Color(0xFFC9FCCA);
const Color _searchAccent = Color(0xFFC2BDF0);
const Color _cameraAccentDark = Color(0xFF2E6B4A);
const Color _searchAccentDark = Color(0xFF594A9E);

class MedicationExplorerScreen extends StatefulWidget {
  const MedicationExplorerScreen({super.key});

  @override
  State<MedicationExplorerScreen> createState() =>
      _MedicationExplorerScreenState();
}

class _MedicationExplorerScreenState extends State<MedicationExplorerScreen> {
  final OcrService _ocr = OcrService();
  final MedicationExplorerService _service = MedicationExplorerService();
  final SpeechToText _speech = SpeechToText();
  final TextEditingController _queryController = TextEditingController();

  late final Directory _ocrTempDir;
  late final File _ocrTempFile;
  late final Directory _visionTempDir;
  late final File _visionModelFile;
  late final File _visionLabelsFile;

  CameraController? _cameraController;
  List<CameraDescription> _availableCameras = const [];
  VisionDetectionWorker? _visionWorker;
  StreamSubscription<VisionFrameResult>? _visionSubscription;

  DateTime _lastOcrAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _busyOcr = false;
  bool _cameraEnabled = true;
  bool _liveVisionEnabled = true;
  bool _isListening = false;
  bool _cameraReady = false;
  bool _visionReady = false;
  bool _visionAssetsReady = false;
  bool _initializingCamera = false;
  bool _initializingVision = false;
  bool _torchEnabled = false;
  bool _visionSupported = true;
  String _visionStatus = 'A carregar modelo de visão...';
  String? _speechLocaleId;
  Size _frameSize = const Size(1, 1);
  int _frameId = 0;
  bool _processingFrame = false;
  String? _cameraError;

  _ExplorerMode _mode = _ExplorerMode.camera;

  String _lastOcrSnippet = '';
  String _lastDetectedTags = '';

  List<MedicationMatch> _visionMatches = const [];
  List<MedicationMatch> _ocrMatches = const [];
  List<MedicationMatch> _manualMatches = const [];
  List<MedicationMatch> _matches = const [];
  List<Map<String, dynamic>> _detections = const [];

  @override
  void initState() {
    super.initState();
    _ocrTempDir = Directory.systemTemp.createTempSync('safemed_ocr');
    _ocrTempFile = File('${_ocrTempDir.path}/frame.jpg');
    _visionTempDir = Directory.systemTemp.createTempSync('safemed_yolo');
    _visionModelFile = File('${_visionTempDir.path}/med_recog_best_int8.tflite');
    _visionLabelsFile = File('${_visionTempDir.path}/labels.txt');
    _bootstrapAsync();
  }

  Future<void> _bootstrapAsync() async {
    await _prepareVisionAssets();
    if (!mounted) return;
    await _initializeCamera();
    if (!mounted) return;
    unawaited(_initializeVisionWorker());
  }

  Future<void> _selectCameraMode() async {
    if (!mounted) return;
    setState(() {
      _mode = _ExplorerMode.camera;
      _cameraEnabled = true;
      _isListening = false;
    });
    await _maybeStartCameraStream();
  }

  Future<void> _selectManualMode() async {
    if (!mounted) return;
    setState(() {
      _mode = _ExplorerMode.manual;
      _cameraEnabled = false;
      _isListening = false;
    });
    await _stopCameraStream();
    try {
      await _speech.stop();
    } catch (_) {}
  }

  Future<void> _prepareVisionAssets() async {
    try {
      final modelBytes = await rootBundle.load(
        'assets/yolo11s/tflite/med_recog_best_int8.tflite',
      );
      final labels = await rootBundle.loadString('assets/yolo11s/tflite/labels.txt');
      if (modelBytes.lengthInBytes == 0 || labels.trim().isEmpty) {
        throw StateError('Model asset data is empty.');
      }
      await _visionModelFile.writeAsBytes(
        modelBytes.buffer.asUint8List(),
        flush: true,
      );
      await _visionLabelsFile.writeAsString(labels, flush: true);
      if (mounted) {
        setState(() => _visionAssetsReady = true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _visionAssetsReady = false;
          _visionSupported = true;
          _visionStatus = 'YOLO indisponível: $e';
        });
      }
    }
  }

  Future<void> _initializeVisionWorker() async {
    if (!_visionAssetsReady) return;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      if (mounted) {
        setState(() {
          _visionSupported = false;
          _visionStatus = 'Visão computacional disponível apenas no Android.';
        });
      }
      return;
    }

    _initializingVision = true;
    if (mounted) {
      setState(() => _visionStatus = 'A iniciar inferência YOLO...');
    }

    try {
      final worker = await VisionDetectionWorker.start(
        rootToken: ServicesBinding.rootIsolateToken!,
        modelPath: _visionModelFile.path,
        labelsPath: _visionLabelsFile.path,
        modelVersion: 'yolov11',
        isAsset: false,
        numThreads: 2,
        useGpu: true,
        quantization: true,
        rotation: 90,
      );
      _visionWorker = worker;
      _visionSubscription = worker.results.listen(_handleVisionResult);
      if (mounted) {
        setState(() {
          _visionReady = true;
          _visionStatus = 'Modelo pronto';
        });
      }
      await _maybeStartCameraStream();
    } catch (e) {
      if (mounted) {
        setState(() {
          _visionReady = false;
          _visionSupported = true;
          _visionStatus = 'YOLO desativado: $e';
        });
      }
    } finally {
      _initializingVision = false;
    }
  }

  Future<void> _initializeCamera({CameraDescription? preferredCamera}) async {
    _initializingCamera = true;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw StateError('Nenhuma câmara disponível.');
      }
      _availableCameras = cameras;
      final selectedCamera = preferredCamera ??
          cameras.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.back,
            orElse: () => cameras.first,
          );

      final controller = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await controller.initialize();

      final oldController = _cameraController;
      _cameraController = controller;
      if (mounted) {
        setState(() {
          _cameraReady = true;
          _cameraError = null;
        });
      }
      await oldController?.dispose();
      await _maybeStartCameraStream();
    } catch (e) {
      if (mounted) {
        setState(() {
          _cameraReady = false;
          _cameraError = e.toString();
        });
      }
    } finally {
      _initializingCamera = false;
    }
  }

  Future<void> _maybeStartCameraStream() async {
    if (!_cameraEnabled || !_liveVisionEnabled || !_visionReady || !_cameraReady) {
      return;
    }
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isStreamingImages) return;

    try {
      await controller.startImageStream(_processCameraImage);
    } catch (_) {}
  }

  Future<void> _stopCameraStream() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;
    if (!controller.value.isStreamingImages) return;
    try {
      await controller.stopImageStream();
    } catch (_) {}
  }

  void _processCameraImage(CameraImage image) {
    if (!_cameraEnabled || !_liveVisionEnabled || !_visionReady) return;
    if (_processingFrame || _visionWorker == null) return;

    _processingFrame = true;
    _frameId += 1;
    _frameSize = Size(image.width.toDouble(), image.height.toDouble());

    _visionWorker!.sendFrame(
      frameId: _frameId,
      bytesList: image.planes.map((plane) => plane.bytes).toList(growable: false),
      imageHeight: image.height,
      imageWidth: image.width,
      iouThreshold: 0.4,
      confThreshold: 0.2,
      classThreshold: 0.2,
    );
  }

  void _handleVisionResult(VisionFrameResult result) {
    if (!mounted) return;

    final detections = result.detections;
    final tags = detections
        .map((detection) => (detection['tag'] ?? 'unknown').toString())
        .where((tag) => tag.trim().isNotEmpty)
        .toSet()
        .toList();

    final visionMatches = <MedicationMatch>[];
    for (final tag in tags) {
      visionMatches.addAll(_service.searchText(tag, source: 'vision'));
    }

    setState(() {
      _detections = detections;
      _lastDetectedTags = tags.isEmpty ? '' : tags.join(', ');
      _visionMatches = visionMatches;
      _processingFrame = false;
    });

    _recomputeMatches();
  }

  void _handleOcrText(String text) {
    final matches = _service.searchText(text, source: 'ocr');
    final snippet = text.replaceAll(RegExp(r'\s+'), ' ');
    setState(() {
      _lastOcrSnippet = snippet.length > 120 ? '${snippet.substring(0, 120)}...' : snippet;
      _ocrMatches = matches;
    });
    _recomputeMatches();
  }

  void _searchFromInput() {
    final text = _queryController.text.trim();
    final matches = text.isEmpty
        ? const <MedicationMatch>[]
        : _service.searchText(text, source: 'manual');
    setState(() => _manualMatches = matches);
    _recomputeMatches();
  }

  void _clearSearch() {
    _queryController.clear();
    setState(() => _manualMatches = const []);
    _recomputeMatches();
  }

  void _recomputeMatches() {
    final map = <String, MedicationMatch>{};
    for (final match in _manualMatches) {
      map.putIfAbsent(match.name, () => match);
    }
    for (final match in _ocrMatches) {
      map.putIfAbsent(match.name, () => match);
    }
    for (final match in _visionMatches) {
      map.putIfAbsent(match.name, () => match);
    }
    final list = map.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    setState(() => _matches = list);
  }

  Future<void> _captureOcrPhoto() async {
    final String? recognizedText = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const OcrScreen()),
    );

    if (recognizedText == null || recognizedText.trim().isEmpty) return;
    _handleOcrText(recognizedText);
  }

  Future<String?> _resolveSpeechLocaleId() async {
    if (_speechLocaleId != null) {
      return _speechLocaleId;
    }

    try {
      final locales = await _speech.locales();
      const preferredLocales = ['pt_BR', 'pt_PT'];

      for (final preferred in preferredLocales) {
        for (final locale in locales) {
          if (locale.localeId == preferred) {
            _speechLocaleId = locale.localeId;
            return _speechLocaleId;
          }
        }
      }

      for (final locale in locales) {
        if (locale.localeId.toLowerCase().startsWith('pt')) {
          _speechLocaleId = locale.localeId;
          return _speechLocaleId;
        }
      }
    } catch (_) {}

    try {
      final systemLocale = await _speech.systemLocale();
      _speechLocaleId = systemLocale?.localeId;
    } catch (_) {}

    return _speechLocaleId;
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      if (!mounted) return;
      setState(() => _isListening = false);
      return;
    }

    final available = await _speech.initialize();
    if (!available || !mounted) return;

    final localeId = await _resolveSpeechLocaleId();
    setState(() => _isListening = true);
    await _speech.listen(
      localeId: localeId,
      onResult: (result) {
        final text = result.recognizedWords;
        if (text.isEmpty || !mounted) return;
        _queryController.text = text;
        _queryController.selection = TextSelection.fromPosition(
          TextPosition(offset: text.length),
        );
        if (result.finalResult) {
          _searchFromInput();
          setState(() => _isListening = false);
        }
      },
    );
  }

  Future<void> _toggleTorch() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;
    try {
      final nextMode = _torchEnabled ? FlashMode.off : FlashMode.torch;
      await controller.setFlashMode(nextMode);
      if (mounted) {
        setState(() => _torchEnabled = !_torchEnabled);
      }
    } catch (_) {}
  }

  Future<void> _switchCamera() async {
    if (_availableCameras.length < 2) return;
    final controller = _cameraController;
    final currentName = controller?.description.name;
    final currentIndex = _availableCameras.indexWhere(
      (camera) => camera.name == currentName,
    );
    final nextIndex = currentIndex < 0
        ? 0
        : (currentIndex + 1) % _availableCameras.length;
    await _stopCameraStream();
    await controller?.dispose();
    await _initializeCamera(preferredCamera: _availableCameras[nextIndex]);
  }

  Future<void> _toggleCameraEnabled() async {
    final nextValue = !_cameraEnabled;
    setState(() {
      _cameraEnabled = nextValue;
      if (!nextValue) {
        _isListening = false;
      }
    });
    if (nextValue) {
      await _maybeStartCameraStream();
    } else {
      await _stopCameraStream();
      await _speech.stop();
    }
  }

  void _toggleLiveVision(bool value) {
    setState(() => _liveVisionEnabled = value);
    if (!value) {
      _stopCameraStream();
    } else {
      _maybeStartCameraStream();
    }
  }

  void _enableCamera() {
    _toggleCameraEnabled();
  }

  @override
  void dispose() {
    _queryController.dispose();
    _speech.stop();
    _visionSubscription?.cancel();
    _visionWorker?.dispose();
    _cameraController?.dispose();
    _ocr.dispose();
    try {
      _ocrTempFile.deleteSync();
    } catch (_) {}
    try {
      _visionModelFile.deleteSync();
    } catch (_) {}
    try {
      _visionLabelsFile.deleteSync();
    } catch (_) {}
    try {
      _ocrTempDir.deleteSync(recursive: true);
    } catch (_) {}
    try {
      _visionTempDir.deleteSync(recursive: true);
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medication Explorer'),
        actions: [
          IconButton(
            icon: Icon(_cameraEnabled ? Icons.videocam : Icons.videocam_off),
            onPressed: _toggleCameraEnabled,
            tooltip: _cameraEnabled ? 'Desativar câmara' : 'Ativar câmara',
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            onPressed: _switchCamera,
            tooltip: 'Trocar câmara',
          ),
          IconButton(
            icon: Icon(_torchEnabled ? Icons.flash_on : Icons.flash_off),
            onPressed: _toggleTorch,
            tooltip: 'Flash',
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.surface,
              theme.colorScheme.surfaceContainerHighest.withOpacity(0.55),
            ],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _ExplorerHeroCard(
                cameraEnabled: _cameraEnabled,
                onToggleCamera: _selectCameraMode,
                onSearchWithoutCamera: _selectManualMode,
              ),
              const SizedBox(height: 10),
              const SizedBox(height: 16),
              if (_mode == _ExplorerMode.camera) ...[
                _SectionHeader(
                  title: 'Câmara e OCR',
                  subtitle:
                      'Deteção de medicamentos, leitura de rótulos e inferência em tempo real.',
                  accent: _cameraAccent,
                  accentDark: _cameraAccentDark,
                  icon: Icons.camera_alt_outlined,
                ),
                const SizedBox(height: 12),
                _CameraPanel(
                  cameraController: _cameraController,
                  cameraReady: _cameraReady,
                  cameraEnabled: _cameraEnabled,
                  visionReady: _visionReady,
                  visionSupported: _visionSupported,
                  visionStatus: _visionStatus,
                  liveVisionEnabled: _liveVisionEnabled,
                  onToggleLiveVision: _toggleLiveVision,
                  onCaptureOcrPhoto: _captureOcrPhoto,
                  onEnableCamera: _enableCamera,
                  onRefreshStream: _maybeStartCameraStream,
                  detections: _detections,
                  frameSize: _frameSize,
                  lastDetectedTags: _lastDetectedTags,
                  accent: _cameraAccent,
                  accentDark: _cameraAccentDark,
                ),
              ],
              const SizedBox(height: 20),
              if (_mode == _ExplorerMode.manual) ...[
                _SectionHeader(
                  title: 'Pesquisa manual',
                  subtitle:
                      'Escreva, fale ou cole termos para procurar sintomas, nomes e substâncias ativas sem usar a câmara.',
                  accent: _searchAccent,
                  accentDark: _searchAccentDark,
                  icon: Icons.search,
                ),
                const SizedBox(height: 12),
                _SearchPanel(
                  controller: _queryController,
                  isListening: _isListening,
                  onSearch: _searchFromInput,
                  onSpeak: _toggleListening,
                  onClear: _clearSearch,
                  accent: _searchAccent,
                  accentDark: _searchAccentDark,
                  quickActions: const [
                    ('Febre', 'febre'),
                    ('Dor de cabeça', 'dor de cabeca'),
                    ('Azia', 'azia'),
                    ('Tosse', 'tosse'),
                  ],
                  onQuickSearch: (value) {
                    _queryController.text = value;
                    _searchFromInput();
                  },
                ),
              ],
              const SizedBox(height: 20),
              _SectionHeader(
                title: 'Compatibilidades',
                subtitle:
                    'Resultados combinados a partir da visão, OCR e pesquisa manual.',
                accent: theme.colorScheme.tertiaryContainer,
                accentDark: theme.colorScheme.tertiary,
                icon: Icons.checklist_outlined,
              ),
              const SizedBox(height: 12),
              if (_matches.isEmpty)
                const _EmptyState()
              else
                ..._matches.map(
                  (match) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _MatchCard(match: match),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color accent;
  final Color accentDark;
  final IconData icon;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.accentDark,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: accent.withOpacity(0.35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentDark.withOpacity(0.22)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: accentDark.withOpacity(0.16),
            child: Icon(icon, size: 18, color: accentDark),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(subtitle, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExplorerHeroCard extends StatelessWidget {
  final bool cameraEnabled;
  final VoidCallback onToggleCamera;
  final VoidCallback onSearchWithoutCamera;

  const _ExplorerHeroCard({
    required this.cameraEnabled,
    required this.onToggleCamera,
    required this.onSearchWithoutCamera,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            _cameraAccent.withOpacity(0.88),
            _searchAccent.withOpacity(0.74),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: theme.colorScheme.surface,
                  child: Icon(
                    Icons.medical_services_outlined,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Exploração de medicamentos unificada',
                    style: theme.textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Use a visão para reconhecer embalagens, filtre com texto ou voz e compare rapidamente sintomas, nomes e substâncias ativas.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: onToggleCamera,
                    style: 
                      cameraEnabled
                          ? ElevatedButton.styleFrom(
                              backgroundColor: _cameraAccent,
                              foregroundColor: _cameraAccentDark,
                            )
                          : ElevatedButton.styleFrom(
                              backgroundColor: _cameraAccent.withOpacity(0.50),
                              foregroundColor: _cameraAccentDark.withOpacity(0.50),
                    ),
                    icon: Icon(cameraEnabled
                          ? Icons.videocam
                          : Icons.videocam_off),
                    label: Text('Pesquisa inteligente com câmara'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onSearchWithoutCamera,
                    style: 
                      cameraEnabled
                          ? OutlinedButton.styleFrom(
                              foregroundColor: _searchAccentDark.withOpacity(0.50),
                              side: BorderSide(color: _searchAccent.withOpacity(0.50)),

                            )
                          : OutlinedButton.styleFrom(
                              foregroundColor: _searchAccentDark,
                              side: BorderSide(color: _searchAccent),
                    ),
                    icon: const Icon(Icons.search),
                    label: const Text('Pesquisa manual'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraPanel extends StatelessWidget {
  final CameraController? cameraController;
  final bool cameraReady;
  final bool cameraEnabled;
  final bool visionReady;
  final bool visionSupported;
  final String visionStatus;
  final bool liveVisionEnabled;
  final ValueChanged<bool> onToggleLiveVision;
  final VoidCallback onCaptureOcrPhoto;
  final VoidCallback onEnableCamera;
  final Future<void> Function() onRefreshStream;
  final List<Map<String, dynamic>> detections;
  final Size frameSize;
  final String lastDetectedTags;
  final Color accent;
  final Color accentDark;

  const _CameraPanel({
    required this.cameraController,
    required this.cameraReady,
    required this.cameraEnabled,
    required this.visionReady,
    required this.visionSupported,
    required this.visionStatus,
    required this.liveVisionEnabled,
    required this.onToggleLiveVision,
    required this.onCaptureOcrPhoto,
    required this.onEnableCamera,
    required this.onRefreshStream,
    required this.detections,
    required this.frameSize,
    required this.lastDetectedTags,
    required this.accent,
    required this.accentDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canShowPreview = cameraEnabled && cameraReady && cameraController != null;
    return Card(
      elevation: 0,
      color: accent.withOpacity(0.34),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: accentDark.withOpacity(0.20)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Legenda da visão',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: accentDark,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 8),
            _StatusCard(
              accent: accentDark,
              visionStatus: visionStatus,
              detections: detections,
              tags: lastDetectedTags,
              cameraEnabled: cameraEnabled,
              liveVisionEnabled: liveVisionEnabled,
            ),
            const SizedBox(height: 8),
            AspectRatio(
              aspectRatio: cameraController?.value.aspectRatio ?? 4 / 5,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (canShowPreview)
                      CameraPreview(cameraController!)
                    else
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              accent.withOpacity(0.82),
                              Colors.white.withOpacity(0.90),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.videocam_off,
                                size: 54,
                                color: accentDark,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                cameraEnabled
                                    ? (cameraReady
                                        ? 'Câmara pronta'
                                        : 'A preparar a câmara...')
                                    : 'Câmara desativada',
                                style: theme.textTheme.titleMedium,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                !visionSupported
                                    ? visionStatus
                                    : cameraEnabled
                                        ? 'A visualização fica aqui e os resultados aparecem sobrepostos.'
                                        : 'Pode continuar a pesquisar por texto ou voz.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 12),
                              FilledButton.tonal(
                                onPressed: onEnableCamera,
                                child: Text(
                                  cameraEnabled ? 'Suspender câmara' : 'Ativar câmara',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (canShowPreview && liveVisionEnabled && visionReady)
                      Positioned.fill(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return CustomPaint(
                              painter: YoloPainter(
                                detections: detections,
                                imageSize: frameSize,
                                screenSize: constraints.biggest,
                                boxColor: accentDark,
                                labelBackgroundColor: accentDark,
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _LabeledActionButton(
                  icon: Icons.document_scanner,
                  label: 'OCR',
                  tooltip: 'Capturar rótulo para OCR',
                  onPressed: onCaptureOcrPhoto,
                  accent: accentDark,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FilterChip(
                      label: const Text('Live Vision'),
                      selected: liveVisionEnabled,
                      onSelected: onToggleLiveVision,
                      avatar: Icon(
                        liveVisionEnabled ? Icons.visibility : Icons.visibility_off,
                        size: 18,
                        color: liveVisionEnabled ? accentDark : theme.colorScheme.onSurfaceVariant,
                      ),
                      side: BorderSide(color: accentDark.withOpacity(0.18)),
                      backgroundColor: theme.colorScheme.surface.withOpacity(0.75),
                      selectedColor: accent.withOpacity(0.28),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onRefreshStream,
                icon: const Icon(Icons.refresh),
                label: const Text('Atualizar stream'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchPanel extends StatelessWidget {
  final TextEditingController controller;
  final bool isListening;
  final VoidCallback onSearch;
  final VoidCallback onSpeak;
  final VoidCallback onClear;
  final List<(String, String)> quickActions;
  final ValueChanged<String> onQuickSearch;
  final Color accent;
  final Color accentDark;

  const _SearchPanel({
    required this.controller,
    required this.isListening,
    required this.onSearch,
    required this.onSpeak,
    required this.onClear,
    required this.quickActions,
    required this.onQuickSearch,
    required this.accent,
    required this.accentDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: accent.withOpacity(0.36),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: accentDark.withOpacity(0.20)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) {
                return TextField(
                  controller: controller,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => onSearch(),
                  decoration: InputDecoration(
                    labelText:
                        'Escreva sintomas, medicamento ou substância ativa',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: value.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: onClear,
                            icon: const Icon(Icons.clear),
                          ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onSearch,
                    icon: const Icon(Icons.manage_search),
                    label: const Text('Procurar'),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.tonalIcon(
                  onPressed: onSpeak,
                  icon: Icon(isListening ? Icons.mic_off : Icons.mic),
                  label: Text(isListening ? 'Parar' : 'Falar'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text('Sugestões rápidas', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: quickActions
                  .map(
                    (action) => ActionChip(
                      label: Text(action.$1),
                      onPressed: () => onQuickSearch(action.$2),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _LabeledActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String tooltip;
  final VoidCallback onPressed;
  final Color accent;

  const _LabeledActionButton({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.onPressed,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: accent.withOpacity(0.14),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent.withOpacity(0.24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: accent),
              const SizedBox(height: 4),
              Text(
                label,
                style: theme.textTheme.labelSmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final Color accent;
  final String visionStatus;
  final List<Map<String, dynamic>> detections;
  final String tags;
  final bool cameraEnabled;
  final bool liveVisionEnabled;

  const _StatusCard({
    required this.accent,
    required this.visionStatus,
    required this.detections,
    required this.tags,
    required this.cameraEnabled,
    required this.liveVisionEnabled,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final detectionCount = detections.length;
    final detectionText = detectionCount == 0
        ? 'Aguardando deteções...'
        : '$detectionCount objeto(s) detetado(s)';
    return Card(
      color: theme.colorScheme.surface.withOpacity(0.92),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: accent.withOpacity(0.28)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              cameraEnabled
                  ? detectionText
                  : 'Câmara desativada',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 2),
            Text(visionStatus, style: theme.textTheme.bodySmall),
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                'Classes: $tags',
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (!liveVisionEnabled) ...[
              const SizedBox(height: 2),
              Text(
                'Live Vision pausado',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Point the camera at a medication label or describe a symptom to see matches.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  final MedicationMatch match;

  const _MatchCard({required this.match});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final aliasText = match.aliases.isEmpty
        ? 'No common aliases found.'
        : 'Aliases: ${match.aliases.take(4).join(', ')}';
    final (label, color) = switch (match.source) {
      'vision' => ('Visão', _cameraAccentDark),
      'ocr' => ('OCR', Colors.deepOrange),
      'manual' => ('Manual', _searchAccentDark),
      'symptom' => ('Sintoma', Colors.teal),
      'barcode' => ('Barcode', Colors.indigo),
      _ => ('Match', theme.colorScheme.primary),
    };
    return Card(
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(match.name, style: theme.textTheme.titleMedium),
                ),
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(label),
                  labelStyle: TextStyle(color: color),
                  side: BorderSide(color: color.withOpacity(0.24)),
                  backgroundColor: color.withOpacity(0.08),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(match.reason, style: theme.textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(aliasText, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
