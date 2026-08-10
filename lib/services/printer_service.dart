import 'dart:io';
import 'dart:typed_data';
import 'package:blue_thermal_printer/blue_thermal_printer.dart' as android_bt;
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as ios_ble;
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';

enum PrinterConnectionStatus {
  disconnected,
  connecting,
  connected,
  printing,
  error,
}

class AppPrinterDevice {
  final String name;
  final String address;
  final dynamic nativeDevice;
  final bool isBle;

  AppPrinterDevice({
    required this.name,
    required this.address,
    required this.nativeDevice,
    this.isBle = false,
  });
}

class PrinterService {
  final android_bt.BlueThermalPrinter _androidBt =
      android_bt.BlueThermalPrinter.instance;

  // iOS BLE state
  ios_ble.BluetoothDevice? _bleConnectedDevice;
  ios_ble.BluetoothCharacteristic? _bleWriteCharacteristic;

  PrinterConnectionStatus _status = PrinterConnectionStatus.disconnected;
  List<AppPrinterDevice> _devices = [];
  AppPrinterDevice? _selectedDevice;

  PrinterConnectionStatus get status => _status;
  List<AppPrinterDevice> get devices => List.unmodifiable(_devices);
  AppPrinterDevice? get selectedDevice => _selectedDevice;
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

  Future<List<AppPrinterDevice>> getDevices() async {
    try {
      await checkAndRequestPermissions();

      if (Platform.isAndroid) {
        final rawDevices = await _androidBt.getBondedDevices();
        _devices = rawDevices
            .map((d) => AppPrinterDevice(
                  name: (d.name != null && d.name!.isNotEmpty)
                      ? d.name!
                      : "Bluetooth Printer",
                  address: d.address ?? "",
                  nativeDevice: d,
                  isBle: false,
                ))
            .toList();
        return _devices;
      } else if (Platform.isIOS) {
        // iOS BLE Scanning via FlutterBluePlus
        final results = <AppPrinterDevice>[];

        if (!ios_ble.FlutterBluePlus.isScanningNow) {
          await ios_ble.FlutterBluePlus.startScan(
              timeout: const Duration(seconds: 4));
        }

        final scanSubscription =
            ios_ble.FlutterBluePlus.scanResults.listen((scans) {
          for (final r in scans) {
            final devName = r.device.platformName.isNotEmpty
                ? r.device.platformName
                : (r.advertisementData.advName.isNotEmpty
                    ? r.advertisementData.advName
                    : "Bluetooth Printer");

            final devId = r.device.remoteId.str;
            if (devName.isNotEmpty &&
                !results.any((element) => element.address == devId)) {
              results.add(AppPrinterDevice(
                name: devName,
                address: devId,
                nativeDevice: r.device,
                isBle: true,
              ));
            }
          }
        });

        await Future.delayed(const Duration(seconds: 4));
        await ios_ble.FlutterBluePlus.stopScan();
        await scanSubscription.cancel();

        _devices = results;
        return _devices;
      }
      return [];
    } catch (e) {
      debugPrint('[PrinterService] getDevices error: $e');
      return [];
    }
  }

  Future<bool> connect(AppPrinterDevice device) async {
    _status = PrinterConnectionStatus.connecting;
    try {
      if (Platform.isAndroid && !device.isBle) {
        final androidDevice =
            device.nativeDevice as android_bt.BluetoothDevice;
        final isCurrentlyConnected = await _androidBt.isConnected ?? false;
        if (isCurrentlyConnected) {
          try {
            await _androidBt.disconnect();
            await Future.delayed(const Duration(milliseconds: 300));
          } catch (_) {}
        }

        final dynamic result = await _androidBt.connect(androidDevice);
        final isNowConnected = await _androidBt.isConnected ?? false;
        if (result == true || isNowConnected) {
          _selectedDevice = device;
          _status = PrinterConnectionStatus.connected;
          return true;
        }
      } else {
        // iOS BLE Connection & GATT Characteristic Discovery
        final bleDev = device.nativeDevice as ios_ble.BluetoothDevice;
        await bleDev.connect(timeout: const Duration(seconds: 8));

        // Minta MTU 247 untuk kecepatan & stabilitas pengiriman data
        try {
          await bleDev.requestMtu(247);
          await Future.delayed(const Duration(milliseconds: 200));
        } catch (_) {}

        final services = await bleDev.discoverServices();
        ios_ble.BluetoothCharacteristic? targetChar;

        // Cari karakteristik GATT — prioritaskan write WITH response (ACK) untuk reliabilitas iOS
        for (final service in services) {
          for (final char in service.characteristics) {
            if (char.properties.write) {
              targetChar = char;
              break;
            }
          }
          if (targetChar != null) break;
        }

        // Fallback: gunakan writeWithoutResponse jika tidak ada yang mendukung write biasa
        if (targetChar == null) {
          for (final service in services) {
            for (final char in service.characteristics) {
              if (char.properties.writeWithoutResponse) {
                targetChar = char;
                break;
              }
            }
            if (targetChar != null) break;
          }
        }

        if (targetChar != null) {
          _bleConnectedDevice = bleDev;
          _bleWriteCharacteristic = targetChar;
          _selectedDevice = device;
          _status = PrinterConnectionStatus.connected;
          debugPrint(
            '[BLE] Connected. Char: ${targetChar.uuid} '
            'write=${targetChar.properties.write} '
            'writeNoResp=${targetChar.properties.writeWithoutResponse}'
          );
          return true;
        } else {
          await bleDev.disconnect();
        }
      }

      _status = PrinterConnectionStatus.disconnected;
      return false;
    } catch (e) {
      debugPrint('[PrinterService] connect error: $e');
      _status = PrinterConnectionStatus.error;
      return false;
    }
  }

  Future<void> disconnect() async {
    try {
      if (Platform.isAndroid &&
          _selectedDevice != null &&
          !_selectedDevice!.isBle) {
        await _androidBt.disconnect();
      } else if (_bleConnectedDevice != null) {
        await _bleConnectedDevice!.disconnect();
        _bleConnectedDevice = null;
        _bleWriteCharacteristic = null;
      }
    } catch (_) {}
    _selectedDevice = null;
    _status = PrinterConnectionStatus.disconnected;
  }

  /// Kirim blok bytes ke BLE printer (iOS) — write WITH ACK (withoutResponse: false)
  /// untuk mencegah silent packet drop di iOS CoreBluetooth.
  /// Chunk 20 bytes adalah ukuran paling aman (BLE 4.0 guaranteed payload).
  Future<void> _bleSend(Uint8List data) async {
    if (_bleWriteCharacteristic == null) return;

    // Selalu gunakan chunk 20 byte — paling kompatibel di semua versi iOS & BLE firmware printer
    const chunkSize = 20;

    // Prioritaskan write WITH response (ACK) agar tiap chunk dikonfirmasi printer.
    // writeWithoutResponse: true adalah fire-and-forget — bisa silently drop packet!
    final useAck = _bleWriteCharacteristic!.properties.write;

    for (int i = 0; i < data.length; i += chunkSize) {
      final end =
          (i + chunkSize < data.length) ? i + chunkSize : data.length;
      final chunk = data.sublist(i, end);

      if (useAck) {
        // Write WITH response: iOS CoreBluetooth menunggu ATT Write Response
        // sebelum melanjutkan — 100% reliable, tidak ada packet drop
        await _bleWriteCharacteristic!.write(chunk, withoutResponse: false);
      } else {
        // Fallback: write without response dengan jeda konservatif
        await _bleWriteCharacteristic!.write(chunk, withoutResponse: true);
        await Future.delayed(const Duration(milliseconds: 30));
      }
    }
  }

  Future<bool> printReceiptImage(Uint8List imageBytes) async {
    if (_status != PrinterConnectionStatus.connected &&
        _selectedDevice == null) {
      return false;
    }

    _status = PrinterConnectionStatus.printing;
    try {
      // Encode gambar ke pita-pita ESC/POS
      final bands = await compute(_buildBands, _EscPosInput(imageBytes, 384));

      if (bands.isEmpty) {
        _status = PrinterConnectionStatus.connected;
        return false;
      }

      if (Platform.isAndroid &&
          _selectedDevice != null &&
          !_selectedDevice!.isBle) {
        // Android Classic SPP: kirim seluruh data sekaligus
        final all = BytesBuilder();
        for (final b in bands) {
          all.add(b);
        }
        await _androidBt.writeBytes(all.toBytes());
      } else {
        // iOS BLE: kirim setiap pita satu per satu dengan jeda antar pita
        // Mencegah overflow buffer RAM printer RPP02N / Rongta / Eppos
        for (int bandIdx = 0; bandIdx < bands.length; bandIdx++) {
          await _bleSend(bands[bandIdx]);

          // 200ms antar pita — cukup waktu bagi printer untuk proses & cetak pita sebelumnya
          // sebelum data pita berikutnya masuk ke buffer.
          if (bandIdx < bands.length - 1) {
            await Future.delayed(const Duration(milliseconds: 200));
          }
        }
      }

      _status = PrinterConnectionStatus.connected;
      return true;
    } catch (e) {
      debugPrint('[PrinterService] printReceiptImage error: $e');
      _status = PrinterConnectionStatus.connected;
      return false;
    }
  }
}

class _EscPosInput {
  final Uint8List bytes;
  final int printerWidth;
  const _EscPosInput(this.bytes, this.printerWidth);
}

// ── Build pita-pita ESC/POS ──────────────────────────────────────────────────
// Mengembalikan List<Uint8List> di mana setiap elemen adalah 1 perintah cetak pita.
// Pita pertama mengandung inisialisasi printer; pita terakhir mengandung feed & cut.
List<Uint8List> _buildBands(_EscPosInput input) {
  final decoded = img.decodeImage(input.bytes);
  if (decoded == null) return [];

  final resized = img.copyResize(
    decoded,
    width: input.printerWidth,
    height: -1,
    interpolation: img.Interpolation.average,
  );

  final gray = img.grayscale(resized);
  final w = gray.width;
  final totalH = gray.height;

  final bytesPerRow = (w + 7) ~/ 8;
  final xL = bytesPerRow & 0xFF;
  final xH = (bytesPerRow >> 8) & 0xFF;

  // Pita pertama: inisialisasi printer
  final initBuilder = BytesBuilder();
  initBuilder.add([0x1B, 0x40]); // ESC @ — reset printer
  initBuilder.add([0x1B, 0x33, 0x00]); // ESC 3 0 — line spacing 0
  initBuilder.add([0x1B, 0x61, 0x01]); // ESC a 1 — center align
  final List<Uint8List> result = [initBuilder.toBytes()];

  // Pita gambar 48px agar aman untuk RAM printer portable (Eppos/RPP02N/Rongta)
  const int maxBandHeight = 48;

  for (int startY = 0; startY < totalH; startY += maxBandHeight) {
    final currentH = (startY + maxBandHeight <= totalH)
        ? maxBandHeight
        : (totalH - startY);

    final pixelRows = Uint8List(bytesPerRow * currentH);

    for (int y = 0; y < currentH; y++) {
      final actualY = startY + y;
      for (int x = 0; x < w; x++) {
        final pixel = gray.getPixel(x, actualY);
        // Threshold: semua piksel dengan luminansi < 200 dicetak (gelap & abu-abu sedang)
        // Tidak ada pengecekan alpha — JPEG tidak punya alpha, PNG screenshot selalu opaque
        final lum = pixel.r.toInt();
        if (lum < 200) {
          final byteIdx = y * bytesPerRow + (x ~/ 8);
          pixelRows[byteIdx] |= (0x80 >> (x % 8));
        }
      }
    }

    final yL = currentH & 0xFF;
    final yH = (currentH >> 8) & 0xFF;

    final bandBuilder = BytesBuilder();
    bandBuilder.add([0x1D, 0x76, 0x30, 0x00, xL, xH, yL, yH]);
    bandBuilder.add(pixelRows);
    result.add(bandBuilder.toBytes());
  }

  // Pita terakhir: feed + cut
  final tailBuilder = BytesBuilder();
  tailBuilder.add([0x0A, 0x0A, 0x0A, 0x0A]); // 4x line feed
  tailBuilder.add([0x1D, 0x56, 0x01]); // GS V 1 — auto cut
  result.add(tailBuilder.toBytes());

  return result;
}
