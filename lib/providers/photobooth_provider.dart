import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../services/camera_service.dart';
import '../services/printer_service.dart';

enum PhotoboothTemplate {
  classicStrip("Classic Strip", "4 foto berderet. Format photobooth klasik.", 4),
  squareGrid("Square Grid", "4 foto kotak. Cocok untuk kolase.", 4),
  bentoStyle("Bento Style", "3 foto asimetris. Modern & dinamis.", 3);

  final String title;
  final String description;
  final int defaultFrameCount;
  const PhotoboothTemplate(this.title, this.description, this.defaultFrameCount);
}

enum RetroFilter {
  monoArcade('Mono Arcade', 'Classic 1-bit high-contrast thermal black & white'),
  sepiaVibe('Sepia Vibe', 'Warm vintage 90s Polaroid tint'),
  vividNeon('Vivid Arcade', 'Punchy neon contrast for group shots'),
  retroGrain('Retro Grain', 'Soft analog film grain texture');

  final String title;
  final String description;
  const RetroFilter(this.title, this.description);
}

class PrintSession {
  final String id;
  final String title;
  final String location;
  final DateTime timestamp;
  final List<String> photoPaths;
  final PhotoboothTemplate template;
  /// Path lokal file gambar strip yang sudah dicetak (PNG)
  final String? stripImagePath;

  PrintSession({
    required this.id,
    required this.title,
    required this.location,
    required this.timestamp,
    required this.photoPaths,
    required this.template,
    this.stripImagePath,
  });
}

class PhotoboothProvider extends ChangeNotifier {
  // Services
  final CameraService _cameraService = CameraService();
  final PrinterService _printerService = PrinterService();

  CameraService get cameraService => _cameraService;
  PrinterService get printerService => _printerService;

  // Selected Photobooth Template
  PhotoboothTemplate _selectedTemplate = PhotoboothTemplate.classicStrip;
  PhotoboothTemplate get selectedTemplate => _selectedTemplate;

  void setSelectedTemplate(PhotoboothTemplate template) {
    _selectedTemplate = template;
    _photoCount = template.defaultFrameCount;
    notifyListeners();
  }

  // Session Config
  int _photoCount = 4;
  int _timerDelaySeconds = 3;
  RetroFilter _selectedFilter = RetroFilter.monoArcade;
  bool _autoPrintOnCapture = true;
  int _copies = 1;

  // Active Session State
  bool _isCapturingSession = false;
  int _currentCountdown = 0;
  int _currentPhotoIndex = 0;
  List<String> _capturedPhotos = [];
  bool _isPrinting = false;

  // Print History & Storage
  final List<PrintSession> _printHistory = [];

  // Getters
  int get photoCount => _photoCount;
  int get timerDelaySeconds => _timerDelaySeconds;
  RetroFilter get selectedFilter => _selectedFilter;
  bool get autoPrintOnCapture => _autoPrintOnCapture;
  int get copies => _copies;
  bool get isCapturingSession => _isCapturingSession;
  int get currentCountdown => _currentCountdown;
  int get currentPhotoIndex => _currentPhotoIndex;
  List<String> get capturedPhotos => List.unmodifiable(_capturedPhotos);
  bool get isPrinting => _isPrinting;
  List<PrintSession> get printHistory => List.unmodifiable(_printHistory);

  List<String> get allGalleryPhotos {
    final list = <String>[];
    for (final session in _printHistory) {
      // Prioritaskan strip image, fallback ke foto individual
      if (session.stripImagePath != null &&
          session.stripImagePath!.isNotEmpty) {
        list.add(session.stripImagePath!);
      } else {
        list.addAll(session.photoPaths);
      }
    }
    return list.reversed.toList();
  }

  // Actions
  void setPhotoCount(int count) {
    _photoCount = count;
    notifyListeners();
  }

  void setTimerDelay(int seconds) {
    _timerDelaySeconds = seconds;
    notifyListeners();
  }

  void setFilter(RetroFilter filter) {
    _selectedFilter = filter;
    notifyListeners();
  }

  void toggleAutoPrint(bool value) {
    _autoPrintOnCapture = value;
    notifyListeners();
  }

  void setCopies(int copiesCount) {
    _copies = copiesCount.clamp(1, 10);
    notifyListeners();
  }

  void addCapturedPhoto(String path) {
    _capturedPhotos.add(path);
    notifyListeners();
  }

  void clearCapturedPhotos() {
    _capturedPhotos = [];
    notifyListeners();
  }

  void reorderPhotos(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    if (oldIndex >= 0 &&
        oldIndex < _capturedPhotos.length &&
        newIndex >= 0 &&
        newIndex <= _capturedPhotos.length) {
      final item = _capturedPhotos.removeAt(oldIndex);
      _capturedPhotos.insert(newIndex, item);
      notifyListeners();
    }
  }

  /// Simpan sesi cetak ke riwayat dengan path strip image
  void saveCurrentSessionToHistory({
    String location = "Malang, ID",
    String? stripImagePath,
  }) {
    if (_capturedPhotos.isEmpty) return;

    final session = PrintSession(
      id: const Uuid().v4(),
      title: _selectedTemplate.title,
      location: location,
      timestamp: DateTime.now(),
      photoPaths: List.from(_capturedPhotos),
      template: _selectedTemplate,
      stripImagePath: stripImagePath,
    );

    _printHistory.insert(0, session);
    notifyListeners();
  }

  /// Simpan strip image bytes ke galeri HP dan ke riwayat cetak.
  /// Mengembalikan path file strip yang tersimpan di local storage.
  Future<String?> saveStripToGalleryAndHistory({
    required Uint8List stripImageBytes,
    String location = "Malang, ID",
  }) async {
    try {
      // 1. Simpan ke file lokal di Application Documents
      final docsDir = await getApplicationDocumentsDirectory();
      final fileName =
          "EPPOS_STRIP_${DateTime.now().millisecondsSinceEpoch}.png";
      final stripFile = File("${docsDir.path}/$fileName");
      await stripFile.writeAsBytes(stripImageBytes);

      // 2. Simpan ke galeri HP (Photos/Gallery app)
      try {
        final hasAccess = await Gal.hasAccess(toAlbum: true);
        if (!hasAccess) {
          await Gal.requestAccess(toAlbum: true);
        }
        await Gal.putImage(stripFile.path, album: "Eppos Photobooth");
      } catch (e) {
        // Galeri gagal, tapi tetap lanjut simpan ke history
        debugPrint('[PhotoboothProvider] Gallery save error: \$e');
      }

      // 3. Simpan ke riwayat cetak di provider
      saveCurrentSessionToHistory(
        location: location,
        stripImagePath: stripFile.path,
      );

      return stripFile.path;
    } catch (e) {
      debugPrint('[PhotoboothProvider] saveStripToGalleryAndHistory error: \$e');
      return null;
    }
  }

  void resetSession() {
    _capturedPhotos = [];
    _currentCountdown = 0;
    _currentPhotoIndex = 0;
    _isCapturingSession = false;
    _isPrinting = false;
    notifyListeners();
  }

  // Generate local JPEG file for simulators/devices without physical camera
  Future<String> _generateRealFallbackPhoto(int index) async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final fileName =
          "PHOTO_${DateTime.now().millisecondsSinceEpoch}_$index.jpg";
      final file = File("${docsDir.path}/$fileName");

      final photo = img.Image(width: 600, height: 450);
      img.fill(photo, color: img.ColorRgb8(240, 240, 240));

      // Draw framing line
      img.drawRect(
        photo,
        x1: 15,
        y1: 15,
        x2: 585,
        y2: 435,
        color: img.ColorRgb8(24, 24, 27),
        thickness: 4,
      );

      final jpegBytes = img.encodeJpg(photo);
      await file.writeAsBytes(jpegBytes);
      return file.path;
    } catch (e) {
      return "";
    }
  }

  // Photobooth Capture Flow
  Future<void> startCaptureSession({required Function onSessionComplete}) async {
    _isCapturingSession = true;
    _capturedPhotos = [];
    _currentPhotoIndex = 0;
    notifyListeners();

    final targetCount = _selectedTemplate.defaultFrameCount;

    for (int i = 0; i < targetCount; i++) {
      _currentPhotoIndex = i + 1;
      // Countdown timer loop
      for (int count = _timerDelaySeconds; count > 0; count--) {
        _currentCountdown = count;
        notifyListeners();
        await Future.delayed(const Duration(seconds: 1));
      }
      _currentCountdown = 0;

      // Try taking photo via CameraService
      final photoFile = await _cameraService.takePicture();
      if (photoFile != null) {
        _capturedPhotos.add(photoFile.path);
      } else {
        // Local fallback image file generated on device
        final generatedPath = await _generateRealFallbackPhoto(i + 1);
        if (generatedPath.isNotEmpty) {
          _capturedPhotos.add(generatedPath);
        }
      }
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 600));
    }

    _isCapturingSession = false;
    notifyListeners();
    onSessionComplete();
  }

  Future<void> printPhotoStrip() async {
    if (_isPrinting) return;
    _isPrinting = true;
    notifyListeners();

    // Save session to local history
    saveCurrentSessionToHistory();

    await Future.delayed(const Duration(seconds: 2));
    _isPrinting = false;
    notifyListeners();
  }
}
