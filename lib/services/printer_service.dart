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
        // iOS BLE Scanning via FlutterBluePlus (dukungan printer Rongta / RPP02N / RTPrinter / Eppos)
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

        final services = await bleDev.discoverServices();
        ios_ble.BluetoothCharacteristic? targetChar;

        for (final service in services) {
          for (final char in service.characteristics) {
            if (char.properties.write ||
                char.properties.writeWithoutResponse) {
              targetChar = char;
              break;
            }
          }
          if (targetChar != null) break;
        }

        if (targetChar != null) {
          _bleConnectedDevice = bleDev;
          _bleWriteCharacteristic = targetChar;
          _selectedDevice = device;
          _status = PrinterConnectionStatus.connected;
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

  Future<bool> printReceiptImage(Uint8List imageBytes) async {
    if (_status != PrinterConnectionStatus.connected &&
        _selectedDevice == null) {
      return false;
    }

    _status = PrinterConnectionStatus.printing;
    try {
      if (Platform.isAndroid &&
          _selectedDevice != null &&
          !_selectedDevice!.isBle) {
        // Android: encode & kirim sekaligus via SPP socket (tidak ada masalah buffer)
        final escPosBytes =
            await compute(_computeEscPos, _EscPosInput(imageBytes, 384));
        if (escPosBytes.isEmpty) {
          _status = PrinterConnectionStatus.connected;
          return false;
        }
        await _androidBt.writeBytes(escPosBytes);
      } else if (_bleWriteCharacteristic != null) {
        // iOS BLE: encode ke pita-pita 48px, kirim satu per satu dengan ACK
        // Mencegah silent packet drop (writeWithoutResponse) & printer RAM overflow
        final bands =
            await compute(_buildIosBands, _EscPosInput(imageBytes, 384));
        if (bands.isEmpty) {
          _status = PrinterConnectionStatus.connected;
          return false;
        }

        // Cek apakah karakteristik mendukung write WITH response
        final useAck = _bleWriteCharacteristic!.properties.write;
        const chunkSize = 20; // 20 byte — BLE 4.0 guaranteed payload

        for (int bandIdx = 0; bandIdx < bands.length; bandIdx++) {
          final band = bands[bandIdx];

          // Kirim 1 pita dalam potongan 20-byte
          for (int i = 0; i < band.length; i += chunkSize) {
            final end = (i + chunkSize < band.length) ? i + chunkSize : band.length;
            final chunk = band.sublist(i, end);

            if (useAck) {
              // Write WITH response: iOS CoreBluetooth menunggu ATT ACK
              // sebelum lanjut — tidak ada packet drop
              await _bleWriteCharacteristic!.write(chunk, withoutResponse: false);
            } else {
              await _bleWriteCharacteristic!.write(chunk, withoutResponse: true);
              await Future.delayed(const Duration(milliseconds: 30));
            }
          }

          // Jeda 200ms antar pita: beri waktu printer RPP02N memproses & cetak
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

// ── Android: encode seluruh gambar ke 1 ESC/POS payload ─────────────────────
Uint8List _computeEscPos(_EscPosInput input) {
  final decoded = img.decodeImage(input.bytes);
  if (decoded == null) return Uint8List(0);

  final resized = img.copyResize(
    decoded,
    width: input.printerWidth,
    height: -1,
    interpolation: img.Interpolation.average,
  );

  final gray = img.grayscale(resized);
  final w = gray.width;
  final h = gray.height;

  final bytesPerRow = (w + 7) ~/ 8;
  final pixelRows = Uint8List(bytesPerRow * h);

  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      final pixel = gray.getPixel(x, y);
      final lum = pixel.r.toInt();
      if (lum < 128) {
        final byteIdx = y * bytesPerRow + (x ~/ 8);
        pixelRows[byteIdx] |= (0x80 >> (x % 8));
      }
    }
  }

  final out = BytesBuilder();
  out.add([0x1B, 0x40]); // ESC @
  out.add([0x1B, 0x33, 0x00]); // ESC 3 0
  out.add([0x1B, 0x61, 0x01]); // ESC a 1

  final xL = bytesPerRow & 0xFF;
  final xH = (bytesPerRow >> 8) & 0xFF;
  final yL = h & 0xFF;
  final yH = (h >> 8) & 0xFF;
  out.add([0x1D, 0x76, 0x30, 0x00, xL, xH, yL, yH]);
  out.add(pixelRows);

  out.add([0x0A, 0x0A, 0x0A, 0x0A]);
  out.add([0x1D, 0x56, 0x01]);

  return out.toBytes();
}

// ── iOS BLE: encode gambar ke List pita ESC/POS 48px ────────────────────────
// Mengirim pita kecil satu per satu mencegah overflow buffer RAM printer RPP02N.
List<Uint8List> _buildIosBands(_EscPosInput input) {
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

  final List<Uint8List> result = [];

  // Pita pertama: inisialisasi printer
  final initBuilder = BytesBuilder();
  initBuilder.add([0x1B, 0x40]); // ESC @ — reset
  initBuilder.add([0x1B, 0x33, 0x00]); // ESC 3 0 — line spacing 0
  initBuilder.add([0x1B, 0x61, 0x01]); // ESC a 1 — center align
  result.add(initBuilder.toBytes());

  // Pita gambar 48px — aman untuk RAM printer portable
  const int bandH = 48;

  for (int startY = 0; startY < totalH; startY += bandH) {
    final currentH =
        (startY + bandH <= totalH) ? bandH : (totalH - startY);

    final pixelRows = Uint8List(bytesPerRow * currentH);

    for (int y = 0; y < currentH; y++) {
      for (int x = 0; x < w; x++) {
        final pixel = gray.getPixel(x, startY + y);
        final lum = pixel.r.toInt();
        if (lum < 128) {
          pixelRows[y * bytesPerRow + (x ~/ 8)] |= (0x80 >> (x % 8));
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
  tailBuilder.add([0x0A, 0x0A, 0x0A, 0x0A]);
  tailBuilder.add([0x1D, 0x56, 0x01]);
  result.add(tailBuilder.toBytes());

  return result;
}
