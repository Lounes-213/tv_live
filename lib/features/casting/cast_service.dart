import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import 'lg_webos_client.dart';

final _log = Logger(printer: SimplePrinter());

class CastDevice {
  final String id;
  final String name;
  final String type;
  final LgWebOsClient? webosClient;

  CastDevice({
    required this.id,
    required this.name,
    required this.type,
    this.webosClient,
  });

  @override
  String toString() => '$name ($type)';
}

class CastService {
  StreamSubscription? _deviceSub;

  final _devicesController = StreamController<List<CastDevice>>.broadcast();
  final Map<String, CastDevice> _devices = {};

  CastDevice? _activeDevice;
  bool _isCasting = false;

  Stream<List<CastDevice>> get devicesStream => _devicesController.stream;
  List<CastDevice> get devices => _devices.values.toList();
  bool get isCasting => _isCasting;
  CastDevice? get activeDevice => _activeDevice;

  Future<void> startDiscovery() async {
    await stopDiscovery();
    _devices.clear();
    _log.i('Cast discovery ready (DLNA unavailable, WebOS only)');
  }

  Future<void> stopDiscovery() async {
    _deviceSub?.cancel();
    _deviceSub = null;
  }

  Future<bool> castTo(CastDevice device, String url, {String title = ''}) async {
    try {
      if (device.type == 'webos' && device.webosClient != null) {
        await device.webosClient!.playMedia(url, title: title);
        _activeDevice = device;
        _isCasting = true;
        _log.i('Casting to ${device.name} via WebOS: $url');
        return true;
      }
      return false;
    } catch (e) {
      _log.e('Cast failed: $e');
      return false;
    }
  }

  Future<void> stopCasting() async {
    try {
      await _activeDevice?.webosClient?.stop();
    } catch (e) {
      _log.e('Stop cast error: $e');
    }
    _activeDevice = null;
    _isCasting = false;
  }

  Future<void> pause() async {
    try {
      await _activeDevice?.webosClient?.pause();
    } catch (e) {
      _log.e('Cast pause error: $e');
    }
  }

  Future<void> resume() async {
    try {
      await _activeDevice?.webosClient?.play();
    } catch (e) {
      _log.e('Cast resume error: $e');
    }
  }

  Future<void> setVolume(int volume) async {
    try {
      await _activeDevice?.webosClient?.setVolume(volume.clamp(0, 100));
    } catch (e) {
      _log.e('Cast volume error: $e');
    }
  }

  Future<bool> switchChannel(String url, {String title = ''}) async {
    if (_activeDevice == null) return false;
    return castTo(_activeDevice!, url, title: title);
  }

  Future<CastDevice?> addManualDevice(String ip) async {
    final isWebOs = await LgWebOsClient.probe(ip);
    if (isWebOs) {
      final client = LgWebOsClient(host: ip);
      final connected = await client.connect();
      String name = 'LG TV ($ip)';
      if (connected) {
        try {
          final info = await client.getSystemInfo();
          final model = info['modelName'] as String? ?? '';
          if (model.isNotEmpty) name = 'LG $model';
        } catch (_) {}
      }
      final device = CastDevice(
        id: 'webos_$ip',
        name: name,
        type: 'webos',
        webosClient: client,
      );
      _devices[device.id] = device;
      _devicesController.add(_devices.values.toList());
      return device;
    }
    return null;
  }

  void dispose() {
    stopCasting();
    stopDiscovery();
    _devicesController.close();
  }
}

final castServiceProvider = Provider<CastService>((ref) {
  final service = CastService();
  ref.onDispose(() => service.dispose());
  return service;
});
