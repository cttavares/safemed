import 'dart:async';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:flutter_vision/flutter_vision.dart';

class VisionFrameResult {
  final int frameId;
  final List<Map<String, dynamic>> detections;
  final String? error;

  const VisionFrameResult({
    required this.frameId,
    required this.detections,
    this.error,
  });

  factory VisionFrameResult.fromMessage(Map<String, dynamic> message) {
    final rawDetections = message['detections'];
    final detections = rawDetections is List
        ? rawDetections
            .whereType<Map>()
            .map((entry) => Map<String, dynamic>.from(entry))
            .toList()
        : <Map<String, dynamic>>[];
    return VisionFrameResult(
      frameId: message['frameId'] as int? ?? -1,
      detections: detections,
      error: message['error'] as String?,
    );
  }
}

class VisionDetectionWorker {
  final ReceivePort _receivePort;
  final StreamController<VisionFrameResult> _resultsController;
  final Completer<void> _readyCompleter;

  Isolate? _isolate;
  SendPort? _commandPort;
  StreamSubscription<dynamic>? _receiveSubscription;
  bool _disposed = false;

  VisionDetectionWorker._(
    this._receivePort,
    this._resultsController,
    this._readyCompleter,
  );

  Stream<VisionFrameResult> get results => _resultsController.stream;

  static Future<VisionDetectionWorker> start({
    required RootIsolateToken rootToken,
    required String modelPath,
    required String labelsPath,
    required String modelVersion,
    required bool isAsset,
    required int numThreads,
    required bool useGpu,
    required bool quantization,
    required int rotation,
  }) async {
    final receivePort = ReceivePort();
    final resultsController = StreamController<VisionFrameResult>.broadcast();
    final readyCompleter = Completer<void>();
    final worker = VisionDetectionWorker._(
      receivePort,
      resultsController,
      readyCompleter,
    );

    worker._receiveSubscription = receivePort.listen((dynamic message) {
      if (message is SendPort) {
        worker._commandPort = message;
        if (!readyCompleter.isCompleted) {
          readyCompleter.complete();
        }
        return;
      }

      if (message is Map) {
        final payload = Map<String, dynamic>.from(message);
        final type = payload['type']?.toString();
        if (type == 'ready' && !readyCompleter.isCompleted) {
          readyCompleter.complete();
          return;
        }
        if (type == 'error') {
          if (!readyCompleter.isCompleted) {
            readyCompleter.completeError(
              Exception(payload['error']?.toString() ?? 'Vision worker failed.'),
            );
            return;
          }
          resultsController.add(
            VisionFrameResult(
              frameId: payload['frameId'] as int? ?? -1,
              detections: const [],
              error: payload['error']?.toString(),
            ),
          );
          return;
        }
        if (type == 'result') {
          resultsController.add(VisionFrameResult.fromMessage(payload));
        }
      }
    });

    worker._isolate = await Isolate.spawn(
      _visionWorkerMain,
      {
        'replyPort': receivePort.sendPort,
        'rootToken': rootToken,
        'modelPath': modelPath,
        'labelsPath': labelsPath,
        'modelVersion': modelVersion,
        'isAsset': isAsset,
        'numThreads': numThreads,
        'useGpu': useGpu,
        'quantization': quantization,
        'rotation': rotation,
      },
    );

    await readyCompleter.future;
    return worker;
  }

  void sendFrame({
    required int frameId,
    required List<Uint8List> bytesList,
    required int imageHeight,
    required int imageWidth,
    double iouThreshold = 0.4,
    double confThreshold = 0.2,
    double classThreshold = 0.2,
  }) {
    if (_disposed) return;
    final commandPort = _commandPort;
    if (commandPort == null) return;

    commandPort.send({
      'type': 'frame',
      'frameId': frameId,
      'bytesList': bytesList,
      'imageHeight': imageHeight,
      'imageWidth': imageWidth,
      'iouThreshold': iouThreshold,
      'confThreshold': confThreshold,
      'classThreshold': classThreshold,
    });
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    try {
      _commandPort?.send({'type': 'close'});
    } catch (_) {}

    await _receiveSubscription?.cancel();
    await _resultsController.close();
    _receivePort.close();
    _isolate?.kill(priority: Isolate.immediate);
  }
}

Future<void> _visionWorkerMain(Map<String, dynamic> message) async {
  final SendPort replyPort = message['replyPort'] as SendPort;
  final RootIsolateToken rootToken = message['rootToken'] as RootIsolateToken;
  final String modelPath = message['modelPath'] as String;
  final String labelsPath = message['labelsPath'] as String;
  final String modelVersion = message['modelVersion'] as String;
  final bool isAsset = message['isAsset'] as bool;
  final int numThreads = message['numThreads'] as int;
  final bool useGpu = message['useGpu'] as bool;
  final bool quantization = message['quantization'] as bool;
  final int rotation = message['rotation'] as int;

  BackgroundIsolateBinaryMessenger.ensureInitialized(rootToken);

  final vision = FlutterVision();
  final commandPort = ReceivePort();

  try {
    await vision.loadYoloModel(
      modelPath: modelPath,
      labels: labelsPath,
      modelVersion: modelVersion,
      isAsset: isAsset,
      numThreads: numThreads,
      useGpu: useGpu,
      quantization: quantization,
      rotation: rotation,
    );

    replyPort.send(commandPort.sendPort);
    replyPort.send({
      'type': 'ready',
      'frameId': -1,
    });

    await for (final dynamic rawMessage in commandPort) {
      if (rawMessage is! Map) continue;
      final packet = Map<String, dynamic>.from(rawMessage);
      final type = packet['type']?.toString();

      if (type == 'close') {
        try {
          await vision.closeYoloModel();
        } catch (_) {}
        commandPort.close();
        Isolate.exit();
      }

      if (type != 'frame') continue;

      final frameId = packet['frameId'] as int? ?? -1;
      final bytesList = (packet['bytesList'] as List?)
          ?.whereType<Uint8List>()
          .toList(growable: false);
      final imageHeight = packet['imageHeight'] as int? ?? 1;
      final imageWidth = packet['imageWidth'] as int? ?? 1;
      final iouThreshold = (packet['iouThreshold'] as num?)?.toDouble();
      final confThreshold = (packet['confThreshold'] as num?)?.toDouble();
      final classThreshold = (packet['classThreshold'] as num?)?.toDouble();

      if (bytesList == null || bytesList.isEmpty) {
        replyPort.send({
          'type': 'result',
          'frameId': frameId,
          'detections': const <Map<String, dynamic>>[],
        });
        continue;
      }

      try {
        final detections = await vision.yoloOnFrame(
          bytesList: bytesList,
          imageHeight: imageHeight,
          imageWidth: imageWidth,
          iouThreshold: iouThreshold,
          confThreshold: confThreshold,
          classThreshold: classThreshold,
        );
        replyPort.send({
          'type': 'result',
          'frameId': frameId,
          'detections': detections,
        });
      } catch (e) {
        replyPort.send({
          'type': 'error',
          'frameId': frameId,
          'error': e.toString(),
        });
      }
    }
  } catch (e) {
    replyPort.send({
      'type': 'error',
      'frameId': -1,
      'error': e.toString(),
    });
  } finally {
    try {
      await vision.closeYoloModel();
    } catch (_) {}
    commandPort.close();
  }
}
