import 'dart:typed_data';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';

enum PrinterConnectionStatus {
  disconnected,
  connecting,
  connected,
  printing,
  error,
}

class PrinterService {
  final BlueThermalPrinter _bluetooth = BlueThermalPrinter.instance;
  PrinterConnectionStatus _status = PrinterConnectionStatus.disconnected;
  List<BluetoothDevice> _devices = [];
  BluetoothDevice? _selectedDevice;

  PrinterConnectionStatus get status => _status;
  List<BluetoothDevice> get devices => List.unmodifiable(_devices);
  BluetoothDevice? get selectedDevice => _selectedDevice;
  bool get isConnected => _status == PrinterConnectionStatus.connected;

  Future<bool> checkAndRequestPermissions() async {
    try {
      final bluetoothStatus = await Permission.bluetooth.request();
      final connectStatus = await Permission.bluetoothConnect.request();
      final scanStatus = await Permission.bluetoothScan.request();
      final locationStatus = await Permission.location.request();
      return (bluetoothStatus.isGranted || connectStatus.isGranted) &&
          (scanStatus.isGranted || locationStatus.isGranted);
    } catch (_) {
      return true;
    }
  }

  Future<List<BluetoothDevice>> getDevices() async {
    try {
      await checkAndRequestPermissions();
      _devices = await _bluetooth.getBondedDevices();
      return _devices;
    } catch (e) {
      return [];
    }
  }

  Future<bool> connect(BluetoothDevice device) async {
    _status = PrinterConnectionStatus.connecting;
    try {
      // Putuskan koneksi lama jika masih terbuka
      final isCurrentlyConnected = await _bluetooth.isConnected ?? false;
      if (isCurrentlyConnected) {
        try {
          await _bluetooth.disconnect();
          await Future.delayed(const Duration(milliseconds: 300));
        } catch (_) {}
      }

      // Hubungkan ke device
      final dynamic result = await _bluetooth.connect(device);

      // Verifikasi koneksi
      final isNowConnected = await _bluetooth.isConnected ?? false;
      if (result == true || isNowConnected) {
        _selectedDevice = device;
        _status = PrinterConnectionStatus.connected;
        return true;
      }

      _status = PrinterConnectionStatus.disconnected;
      return false;
    } catch (e) {
      debugPrint('[PrinterService] connect error: $e');

      // Recover: cek apakah sebenarnya sudah terhubung ("already connected" error)
      try {
        final isConnectedNow = await _bluetooth.isConnected ?? false;
        if (isConnectedNow) {
          _selectedDevice = device;
          _status = PrinterConnectionStatus.connected;
          return true;
        }
      } catch (_) {}

      _status = PrinterConnectionStatus.error;
      return false;
    }
  }

  Future<void> disconnect() async {
    try {
      await _bluetooth.disconnect();
    } catch (_) {}
    _selectedDevice = null;
    _status = PrinterConnectionStatus.disconnected;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PRINT: Kirim gambar ke Eppos thermal printer via ESC/POS GS v 0 raster
  //
  // KENAPA TIDAK pakai plugin printImageBytes():
  //   Bug di Utils.java milik blue_thermal_printer: untuk gambar > 255px
  //   tingginya, parameter yL/yH di GS v 0 dihitung salah (format hex string
  //   yang dibangun punya panjang ganjil, dikrop integer division), sehingga
  //   printer mencetak sisa bitmap data sebagai teks ESC/POS → karakter gajelas.
  //
  // SOLUSI: Bangun ESC/POS GS v 0 sendiri dengan encoding little-endian
  //   yang benar, lalu kirim via writeBytes().
  // ─────────────────────────────────────────────────────────────────────────
  Future<bool> printReceiptImage(Uint8List imageBytes) async {
    // Cek status koneksi fisik dari hardware
    final isHardwareConnected = await _bluetooth.isConnected ?? false;
    if (!isHardwareConnected) {
      _status = PrinterConnectionStatus.disconnected;
      return false;
    }

    _status = PrinterConnectionStatus.printing;
    try {
      // Konversi PNG → ESC/POS raster bitmap di background isolate (non-blocking)
      final escPosBytes = await compute(_computeEscPos, _EscPosInput(imageBytes, 384));

      if (escPosBytes.isEmpty) {
        _status = PrinterConnectionStatus.connected;
        return false;
      }

      // Kirim ESC/POS bytes langsung ke printer via Bluetooth
      await _bluetooth.writeBytes(escPosBytes);

      _status = PrinterConnectionStatus.connected;
      return true;
    } catch (e) {
      debugPrint('[PrinterService] printReceiptImage error: $e');
      _status = PrinterConnectionStatus.connected;
      return false;
    }
  }
}

// ── Input data untuk background isolate ─────────────────────────────────────
class _EscPosInput {
  final Uint8List bytes;
  final int printerWidth;
  const _EscPosInput(this.bytes, this.printerWidth);
}

// ── Konversi PNG/JPG → ESC/POS GS v 0 raster bitmap (jalan di isolate) ─────
//
//  GS v 0 format (raster bit image):
//    1D 76 30 m xL xH yL yH d1..dk
//      m    = 0 (normal density)
//      xL xH = bytes per row (little-endian uint16)
//      yL yH = number of rows (little-endian uint16)
//      data  = 1-bit pixel rows, 1=print dot, 0=blank
//
//  PENTING: xL/xH dan yL/yH harus di-encode little-endian dengan benar.
//  Plugin blue_thermal_printer Utils.java TIDAK melakukan ini dengan benar
//  (bug hex string panjang ganjil untuk height > 255px).
// ─────────────────────────────────────────────────────────────────────────────
Uint8List _computeEscPos(_EscPosInput input) {
  // 1. Decode PNG/JPG ke bitmap
  final decoded = img.decodeImage(input.bytes);
  if (decoded == null) return Uint8List(0);

  // 2. Resize ke lebar printer (384px = 58mm) preserving aspect ratio
  final resized = img.copyResize(
    decoded,
    width: input.printerWidth,
    height: -1, // auto height
    interpolation: img.Interpolation.average,
  );

  // 3. Konversi ke grayscale lalu threshold ke 1-bit
  final gray = img.grayscale(resized);
  final w = gray.width;
  final h = gray.height;

  // Bytes per row = ceil(width / 8)
  final bytesPerRow = (w + 7) ~/ 8;

  // 4. Build pixel data: 1 = cetak dot, 0 = kosong
  final pixelRows = Uint8List(bytesPerRow * h);
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      final pixel = gray.getPixel(x, y);
      final lum = pixel.r.toInt(); // semua channel sama di grayscale
      if (lum < 128) {
        // Pixel gelap → set bit
        final byteIdx = y * bytesPerRow + (x ~/ 8);
        pixelRows[byteIdx] |= (0x80 >> (x % 8));
      }
    }
  }

  // 5. Build ESC/POS command bytes
  final out = BytesBuilder();

  // ESC @ — inisialisasi printer
  out.add([0x1B, 0x40]);

  // ESC 3 0 — line spacing minimal (0)
  out.add([0x1B, 0x33, 0x00]);

  // ESC a 1 — center alignment
  out.add([0x1B, 0x61, 0x01]);

  // GS v 0 — raster bit image
  //   xL xH = bytesPerRow sebagai little-endian uint16
  //   yL yH = h (jumlah baris) sebagai little-endian uint16
  final xL = bytesPerRow & 0xFF;
  final xH = (bytesPerRow >> 8) & 0xFF;
  final yL = h & 0xFF;
  final yH = (h >> 8) & 0xFF;
  out.add([0x1D, 0x76, 0x30, 0x00, xL, xH, yL, yH]);
  out.add(pixelRows);

  // Feed 4 baris + GS V 1 (partial cut)
  out.add([0x0A, 0x0A, 0x0A, 0x0A]);
  out.add([0x1D, 0x56, 0x01]);

  return out.toBytes();
}
