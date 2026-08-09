import 'dart:async';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class PrinterAudioService {
  static final AudioPlayer _player = AudioPlayer();
  static Uint8List? _cachedPrinterWavBytes;

  /// Generate WAV PCM audio data untuk suara motor mesin printer thermal (whirring & feeding sound)
  static Uint8List _generatePrinterWavBytes() {
    if (_cachedPrinterWavBytes != null) return _cachedPrinterWavBytes!;

    const sampleRate = 22050;
    const durationSeconds = 1.8;
    final totalSamples = (sampleRate * durationSeconds).toInt();
    final dataSize = totalSamples * 2; // 16-bit mono
    final fileSize = 44 + dataSize;

    final bytes = ByteData(fileSize);

    // WAV Header
    // RIFF header
    bytes.setUint8(0, 0x52); // R
    bytes.setUint8(1, 0x49); // I
    bytes.setUint8(2, 0x46); // F
    bytes.setUint8(3, 0x46); // F
    bytes.setUint32(4, fileSize - 8, Endian.little);
    bytes.setUint8(8, 0x57); // W
    bytes.setUint8(9, 0x41); // A
    bytes.setUint8(10, 0x56); // V
    bytes.setUint8(11, 0x45); // E

    // fmt subchunk
    bytes.setUint8(12, 0x66); // f
    bytes.setUint8(13, 0x6d); // m
    bytes.setUint8(14, 0x74); // t
    bytes.setUint8(15, 0x20); // ' '
    bytes.setUint32(16, 16, Endian.little); // Subchunk1Size
    bytes.setUint16(20, 1, Endian.little); // AudioFormat (PCM)
    bytes.setUint16(22, 1, Endian.little); // NumChannels (Mono)
    bytes.setUint32(24, sampleRate, Endian.little); // SampleRate
    bytes.setUint32(28, sampleRate * 2, Endian.little); // ByteRate
    bytes.setUint16(32, 2, Endian.little); // BlockAlign
    bytes.setUint16(34, 16, Endian.little); // BitsPerSample

    // data subchunk
    bytes.setUint8(36, 0x64); // d
    bytes.setUint8(37, 0x61); // a
    bytes.setUint8(38, 0x74); // t
    bytes.setUint8(39, 0x61); // a
    bytes.setUint32(40, dataSize, Endian.little);

    // PCM Data: Suara motor stepper thermal printer (frekuensi 320Hz - 480Hz dengan modulasi rachet)
    final rand = Random();
    int offset = 44;

    for (int i = 0; i < totalSamples; i++) {
      final t = i / sampleRate;

      // Modulasi nada stepper motor (rhythmic printer ticks)
      final stepFreq = 360.0 + 80.0 * sin(2 * pi * 8.0 * t);
      final squareWave = sin(2 * pi * stepFreq * t) > 0 ? 0.4 : -0.4;
      final noise = (rand.nextDouble() * 2 - 1) * 0.15; // Mechanical noise

      // Envelope fade in / out
      double envelope = 1.0;
      if (t < 0.1) {
        envelope = t / 0.1;
      } else if (t > durationSeconds - 0.2) {
        envelope = (durationSeconds - t) / 0.2;
      }

      final sampleVal = ((squareWave + noise) * envelope * 12000).clamp(-32768, 32767).toInt();
      bytes.setInt16(offset, sampleVal, Endian.little);
      offset += 2;
    }

    _cachedPrinterWavBytes = bytes.buffer.asUint8List();
    return _cachedPrinterWavBytes!;
  }

  /// Mainkan suara efek mesin printer thermal
  static Future<void> playPrinterSound() async {
    try {
      final wavBytes = _generatePrinterWavBytes();
      await _player.stop();
      await _player.play(BytesSource(wavBytes));
    } catch (e) {
      // Menangani MissingPluginException / error platform audio dengan aman
      debugPrint('[PrinterAudioService] Sound play skipped: $e');
    }
  }

  static Future<void> stop() async {
    try {
      await _player.stop();
    } catch (_) {}
  }
}
