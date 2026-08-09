import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

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
      debugPrint('[CloudStorageService] Firebase init skip: $e');
      _isFirebaseInitialized = false;
    }
  }

  /// Upload byte gambar photo strip ke Cloud Storage & dapatkan Public URL yang 100% bisa discan HP
  static Future<String?> uploadPhotoStrip({
    required Uint8List imageBytes,
    required String sessionId,
  }) async {
    // 1. Coba upload ke Firebase Storage (jika terkonfigurasi)
    if (!_isFirebaseInitialized) {
      await initialize();
    }

    if (_isFirebaseInitialized) {
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
        if (downloadUrl.isNotEmpty) {
          debugPrint('[CloudStorageService] Upload Firebase sukses: $downloadUrl');
          return downloadUrl;
        }
      } catch (e) {
        debugPrint('[CloudStorageService] Firebase Storage upload skip: $e');
      }
    }

    // 2. Fallback Upload Publik Gratis (Catbox API) agar QR Code PASTI 100% bisa dibuka di HP apapun
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://catbox.moe/user/api.php'),
      );
      request.fields['reqtype'] = 'fileupload';
      request.files.add(
        http.MultipartFile.fromBytes(
          'fileToUpload',
          imageBytes,
          filename: 'strip_$sessionId.png',
        ),
      );

      final streamedResponse = await request.send().timeout(const Duration(seconds: 15));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 && response.body.startsWith('http')) {
        final publicUrl = response.body.trim();
        debugPrint('[CloudStorageService] Upload Publik sukses: $publicUrl');
        return publicUrl;
      }
    } catch (e) {
      debugPrint('[CloudStorageService] Public upload fallback error: $e');
    }

    return null;
  }
}

