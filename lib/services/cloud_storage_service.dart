import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class CloudStorageService {
  static bool _isFirebaseInitialized = false;

  /// Inisialisasi Firebase aman (non-blocking if not yet configured)
  static Future<void> initialize() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      _isFirebaseInitialized = true;
    } catch (e) {
      debugPrint('[CloudStorageService] Firebase init skip/error: $e');
      _isFirebaseInitialized = false;
    }
  }

  /// Upload byte gambar photo strip ke Firebase Storage & dapatkan Public Download URL
  static Future<String?> uploadPhotoStrip({
    required Uint8List imageBytes,
    required String sessionId,
  }) async {
    if (!_isFirebaseInitialized) {
      // Coba init ulang
      await initialize();
    }

    if (!_isFirebaseInitialized) {
      debugPrint('[CloudStorageService] Firebase belum dikonfigurasi.');
      return null;
    }

    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('photobooths')
          .child('$sessionId.png');

      final uploadTask = await storageRef.putData(
        imageBytes,
        SettableMetadata(contentType: 'image/png'),
      );

      final downloadUrl = await uploadTask.ref.getDownloadURL();
      debugPrint('[CloudStorageService] Upload sukses: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      debugPrint('[CloudStorageService] Upload error: $e');
      return null;
    }
  }
}
