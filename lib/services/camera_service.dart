import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class CameraService {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;
  bool _isInitialized = false;
  bool _isInitializing = false;
  String? _errorMessage;

  CameraController? get controller => _controller;

  bool get isInitialized =>
      _isInitialized &&
      _controller != null &&
      _controller!.value.isInitialized;

  bool get isInitializing => _isInitializing;

  String? get errorMessage => _errorMessage;

  int get selectedCameraIndex => _selectedCameraIndex;

  int get cameraCount => _cameras.length;

  Future<void> initializeCamera({bool forceReinit = false}) async {
    // Guard: sedang init
    if (_isInitializing) return;

    // Guard: sudah init dan tidak diminta ulang
    if (_isInitialized && !forceReinit) return;

    _isInitializing = true;
    _errorMessage = null;

    try {
      // 1. Dispose controller lama secara aman
      final oldController = _controller;
      _controller = null;
      _isInitialized = false;

      if (oldController != null) {
        try {
          await oldController.dispose();
        } catch (_) {}
        // iOS butuh jeda kecil setelah dispose supaya resource kamera bebas
        if (Platform.isIOS) {
          await Future.delayed(const Duration(milliseconds: 200));
        }
      }

      // 2. Daftar kamera dari hardware
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        _errorMessage = "Tidak ada kamera ditemukan di perangkat ini";
        return;
      }

      // 3. Pilih kamera
      if (!forceReinit) {
        // Default: kamera depan untuk photobooth
        final frontIdx = _cameras.indexWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
        );
        _selectedCameraIndex = (frontIdx != -1) ? frontIdx : 0;
      }
      // Jika forceReinit, _selectedCameraIndex sudah diset oleh switchCamera()

      final cameraToUse = _cameras[_selectedCameraIndex];

      // 4. Buat CameraController
      //    - iOS: gunakan ResolutionPreset.high untuk kualitas, tapi JANGAN set
      //      imageFormatGroup karena iOS punya format sendiri (bgra8888)
      //    - Android: medium sudah cukup untuk photobooth
      final preset = Platform.isIOS
          ? ResolutionPreset.medium   // stabil di iPhone 8+
          : ResolutionPreset.medium;

      _controller = CameraController(
        cameraToUse,
        preset,
        enableAudio: false,
        // Tidak set imageFormatGroup — biarkan camera plugin pilih format
        // terbaik untuk platform masing-masing (iOS/Android)
      );

      await _controller!.initialize();

      // 5. iOS: matikan auto-focus continuous agar tidak lag saat takePicture
      if (Platform.isIOS) {
        try {
          await _controller!.setFocusMode(FocusMode.auto);
        } catch (_) {}
      }

      _isInitialized = true;
      _errorMessage = null;
    } catch (e, stack) {
      debugPrint('[CameraService] init error: $e\n$stack');
      _errorMessage = "Gagal membuka kamera.\nCoba tap Hubungkan Kamera.";
      _isInitialized = false;
      try {
        await _controller?.dispose();
      } catch (_) {}
      _controller = null;
    } finally {
      _isInitializing = false;
    }
  }

  Future<void> switchCamera() async {
    if (_cameras.length <= 1) return;

    // Toggle ke kamera berikutnya
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;

    // Reset guards agar initializeCamera bisa jalan ulang
    _isInitializing = false;
    _isInitialized = false;

    await initializeCamera(forceReinit: true);
  }

  /// Ambil foto dan simpan ke Application Documents
  Future<File?> takePicture() async {
    if (!isInitialized) return null;
    if (_controller!.value.isTakingPicture) return null;

    try {
      final xFile = await _controller!.takePicture();
      final docsDir = await getApplicationDocumentsDirectory();
      final fileName = "EPPOS_${DateTime.now().millisecondsSinceEpoch}.jpg";
      final savedPath = "${docsDir.path}/$fileName";
      return await File(xFile.path).copy(savedPath);
    } catch (e) {
      debugPrint('[CameraService] takePicture error: $e');
      return null;
    }
  }

  Future<void> dispose() async {
    final c = _controller;
    _controller = null;
    _isInitialized = false;
    _isInitializing = false;
    try {
      await c?.dispose();
    } catch (_) {}
  }
}
