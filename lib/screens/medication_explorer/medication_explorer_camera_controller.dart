import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart' as camera_plugin;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../scanner/flutter_vision_isolate.dart';

class MedicationExplorerCameraController extends ChangeNotifier {
  MedicationExplorerCameraController({
    required void Function(List<String> tags) onVisionTagsChanged,
  }) : _onVisionTagsChanged = onVisionTagsChanged {
    _visionTempDir = Directory.systemTemp.createTempSync('safemed_yolo');
    _visionModelFile = File(
      '${_visionTempDir.path}/med_recog_best_int8.tflite',
    );
    _visionLabelsFile = File('${_visionTempDir.path}/labels.txt');
  }

  final void Function(List<String> tags) _onVisionTagsChanged;

  late final Directory _visionTempDir;
  late final File _visionModelFile;
  late final File _visionLabelsFile;

  camera_plugin.CameraController? _cameraController;
  List<camera_plugin.CameraDescription> _availableCameras = const [];
  VisionDetectionWorker? _visionWorker;
  StreamSubscription<VisionFrameResult>? _visionSubscription;

  bool _cameraEnabled = true;
  bool _liveVisionEnabled = true;
  bool _cameraReady = false;
  bool _visionReady = false;
  bool _visionAssetsReady = false;
  bool _initializingCamera = false;
  bool _initializingVision = false;
  bool _torchEnabled = false;
  bool _visionSupported = true;
  String _visionStatus = 'A carregar modelo de visão...';
  Size _frameSize = const Size(1, 1);
  int _frameId = 0;
  bool _processingFrame = false;
  List<Map<String, dynamic>> _detections = const [];
  String _lastDetectedTags = '';
  String? _cameraError;
  bool _disposed = false;

  camera_plugin.CameraController? get cameraController => _cameraController;
  List<camera_plugin.CameraDescription> get availableCameras =>
      _availableCameras;
  bool get cameraEnabled => _cameraEnabled;
  bool get liveVisionEnabled => _liveVisionEnabled;
  bool get cameraReady => _cameraReady;
  bool get visionReady => _visionReady;
  bool get visionAssetsReady => _visionAssetsReady;
  bool get initializingCamera => _initializingCamera;
  bool get initializingVision => _initializingVision;
  bool get torchEnabled => _torchEnabled;
  bool get visionSupported => _visionSupported;
  String get visionStatus => _visionStatus;
  Size get frameSize => _frameSize;
  List<Map<String, dynamic>> get detections => _detections;
  String get lastDetectedTags => _lastDetectedTags;
  String? get cameraError => _cameraError;

  Future<void> bootstrap() async {
    await _prepareVisionAssets();
    if (_disposed) return;
    await initializeCamera();
    if (_disposed) return;
    unawaited(_initializeVisionWorker());
  }

  Future<void> _prepareVisionAssets() async {
    try {
      final modelBytes = await rootBundle.load(
        'assets/yolo11s/tflite/med_recog_best_int8.tflite',
      );
      final labels = await rootBundle.loadString(
        'assets/yolo11s/tflite/labels.txt',
      );
      if (modelBytes.lengthInBytes == 0 || labels.trim().isEmpty) {
        throw StateError('Model asset data is empty.');
      }

      await _visionModelFile.writeAsBytes(
        modelBytes.buffer.asUint8List(),
        flush: true,
      );
      await _visionLabelsFile.writeAsString(labels, flush: true);

      _visionAssetsReady = true;
      notifyListeners();
    } catch (e) {
      _visionAssetsReady = false;
      _visionSupported = true;
      _visionStatus = 'YOLO indisponível: $e';
      notifyListeners();
    }
  }

  Future<void> _initializeVisionWorker() async {
    if (!_visionAssetsReady || _disposed) return;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      _visionSupported = false;
      _visionStatus = 'Visão computacional disponível apenas no Android.';
      notifyListeners();
      return;
    }

    _initializingVision = true;
    _visionStatus = 'A iniciar inferência YOLO...';
    notifyListeners();

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
      _visionReady = true;
      _visionStatus = 'Modelo pronto';
      notifyListeners();
      await _maybeStartCameraStream();
    } catch (e) {
      _visionReady = false;
      _visionSupported = true;
      _visionStatus = 'YOLO desativado: $e';
      notifyListeners();
    } finally {
      _initializingVision = false;
      notifyListeners();
    }
  }

  Future<void> initializeCamera({
    camera_plugin.CameraDescription? preferredCamera,
  }) async {
    _initializingCamera = true;
    notifyListeners();

    try {
      final cameras = await camera_plugin.availableCameras();
      if (cameras.isEmpty) {
        throw StateError('Nenhuma câmara disponível.');
      }
      _availableCameras = cameras;
      final selectedCamera =
          preferredCamera ??
          cameras.firstWhere(
            (camera) =>
                camera.lensDirection == camera_plugin.CameraLensDirection.back,
            orElse: () => cameras.first,
          );

      final controller = camera_plugin.CameraController(
        selectedCamera,
        camera_plugin.ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: camera_plugin.ImageFormatGroup.yuv420,
      );
      await controller.initialize();

      final oldController = _cameraController;
      _cameraController = controller;
      _cameraReady = true;
      _cameraError = null;
      notifyListeners();

      await oldController?.dispose();
      await _maybeStartCameraStream();
    } catch (e) {
      _cameraReady = false;
      _cameraError = e.toString();
      notifyListeners();
    } finally {
      _initializingCamera = false;
      notifyListeners();
    }
  }

  Future<void> setCameraEnabled(bool value) async {
    _cameraEnabled = value;
    if (!value) {
      _torchEnabled = false;
    }
    notifyListeners();

    if (value) {
      await _maybeStartCameraStream();
    } else {
      await _stopCameraStream();
    }
  }

  Future<void> toggleCameraEnabled() => setCameraEnabled(!_cameraEnabled);

  Future<void> setLiveVisionEnabled(bool value) async {
    _liveVisionEnabled = value;
    notifyListeners();
    if (value) {
      await _maybeStartCameraStream();
    } else {
      await _stopCameraStream();
    }
  }

  Future<void> toggleTorch() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;
    try {
      final nextMode = _torchEnabled ? FlashMode.off : FlashMode.torch;
      await controller.setFlashMode(nextMode);
      _torchEnabled = !_torchEnabled;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> switchCamera() async {
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
    await initializeCamera(preferredCamera: _availableCameras[nextIndex]);
  }

  Future<void> refreshStream() => _maybeStartCameraStream();

  Future<void> _maybeStartCameraStream() async {
    if (!_cameraEnabled ||
        !_liveVisionEnabled ||
        !_visionReady ||
        !_cameraReady) {
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

  void _processCameraImage(camera_plugin.CameraImage image) {
    if (!_cameraEnabled || !_liveVisionEnabled || !_visionReady) return;
    if (_processingFrame || _visionWorker == null) return;

    _processingFrame = true;
    _frameId += 1;
    _frameSize = Size(image.width.toDouble(), image.height.toDouble());

    _visionWorker!.sendFrame(
      frameId: _frameId,
      bytesList: image.planes
          .map((plane) => plane.bytes)
          .toList(growable: false),
      imageHeight: image.height,
      imageWidth: image.width,
      iouThreshold: 0.4,
      confThreshold: 0.5,
      classThreshold: 0.2,
    );
  }

  void _handleVisionResult(VisionFrameResult result) {
    if (_disposed) return;

    final detections = result.detections;
    final tags = detections
        .map((detection) => (detection['tag'] ?? 'unknown').toString())
        .where((tag) => tag.trim().isNotEmpty)
        .toSet()
        .toList();

    _detections = detections;
    _lastDetectedTags = tags.isEmpty ? '' : tags.join(', ');
    _processingFrame = false;
    _onVisionTagsChanged(tags);
    notifyListeners();
  }

  Future<void> disposeResources() async {
    _disposed = true;
    await _visionSubscription?.cancel();
    await _visionWorker?.dispose();
    await _cameraController?.dispose();
    try {
      _visionModelFile.deleteSync();
    } catch (_) {}
    try {
      _visionLabelsFile.deleteSync();
    } catch (_) {}
    try {
      _visionTempDir.deleteSync(recursive: true);
    } catch (_) {}
  }
}
