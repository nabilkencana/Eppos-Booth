import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:screenshot/screenshot.dart';
import '../providers/photobooth_provider.dart';
import '../services/cloud_storage_service.dart';
import '../services/printer_audio_service.dart';
import 'printer_settings_screen.dart';
import 'success_screen.dart';

class StripPreviewScreen extends StatefulWidget {
  const StripPreviewScreen({super.key});

  @override
  State<StripPreviewScreen> createState() => _StripPreviewScreenState();
}

class _StripPreviewScreenState extends State<StripPreviewScreen>
    with SingleTickerProviderStateMixin {
  final ScreenshotController _screenshotController = ScreenshotController();
  
  late final AnimationController _ejectionController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  late final Animation<Offset> _slideAnimation = Tween<Offset>(
    begin: const Offset(0, -0.6), // Muncul dari dalam slot mesin
    end: Offset.zero,
  ).animate(
    CurvedAnimation(
      parent: _ejectionController,
      curve: Curves.easeOutCubic,
    ),
  );

  late final Animation<double> _fadeAnimation = Tween<double>(
    begin: 0.1,
    end: 1.0,
  ).animate(
    CurvedAnimation(
      parent: _ejectionController,
      curve: Curves.easeOut,
    ),
  );

  bool _isPrinting = false;

  @override
  void initState() {
    super.initState();
    // Animasi strip keluar dari mesin + mainkan soundtrack/efek suara printer
    _ejectionController.forward(from: 0.0);
    PrinterAudioService.playPrinterSound();
  }


  @override
  void dispose() {
    _ejectionController.dispose();
    PrinterAudioService.stop();
    super.dispose();
  }

  // ── Render nota cetak langsung via Canvas (bypass Flutter widget tree) ─────
  // Menggunakan ui.PictureRecorder + canvas.drawImage setelah foto di-pre-decode
  // agar gambar 100% tersedia saat bitmap PNG di-export untuk dikirim ke printer.
  Future<Uint8List?> _buildReceiptBitmap(
    List<String> photoPaths,
    PhotoboothTemplate template,
  ) async {
    const double pageW = 384.0;
    const double borderW = 6.0;
    const double pad = 16.0;
    const double innerW = pageW - (pad * 2);

    // 1. Pre-decode semua foto ke ui.Image
    final List<ui.Image?> decodedPhotos = [];
    for (final path in photoPaths) {
      try {
        final Uint8List bytes = path.startsWith('http')
            ? Uint8List(0) // network: skip pre-decode, gunakan placeholder
            : File(path).readAsBytesSync();
        if (bytes.isEmpty) {
          decodedPhotos.add(null);
          continue;
        }
        final codec = await ui.instantiateImageCodec(
          bytes,
          targetWidth: innerW.toInt(),
        );
        final frame = await codec.getNextFrame();
        decodedPhotos.add(frame.image);
      } catch (e) {
        debugPrint('[ReceiptBitmap] decode error: $e');
        decodedPhotos.add(null);
      }
    }

    // 2. Hitung tinggi layout berdasarkan template
    double photoSectionH;
    switch (template) {
      case PhotoboothTemplate.singleShot:
        photoSectionH = innerW / 1.25; // landscape-ish
        break;
      case PhotoboothTemplate.classicStrip:
        // 4 foto vertikal
        final frameH = innerW / 1.35;
        photoSectionH = (frameH + 12) * 4 - 12;
        break;
      case PhotoboothTemplate.squareGrid:
        // 2x2 grid
        final frameH = (innerW - 8) / 2;
        photoSectionH = frameH * 2 + 8;
        break;
      case PhotoboothTemplate.bentoStyle:
        // 1 atas + 2 bawah
        final topH = innerW / 1.5;
        final botH = (innerW - 8) / 2;
        photoSectionH = topH + 8 + botH;
        break;
    }

    // Tinggi total halaman
    const double headerH = 120.0;
    const double footerH = 80.0;
    final double totalH = headerH + photoSectionH + footerH;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, pageW, totalH));

    final bgPaint = Paint()..color = const Color(0xFFFFFFFF);
    final blackPaint = Paint()..color = const Color(0xFF000000);
    final borderPaint = Paint()
      ..color = const Color(0xFF18181B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderW;

    // Background putih
    canvas.drawRect(Rect.fromLTWH(0, 0, pageW, totalH), bgPaint);

    // === HEADER ===
    double y = 0;
    // Garis atas tebal
    canvas.drawRect(Rect.fromLTWH(0, y, pageW, 6), blackPaint);
    y += 14;

    _canvasText(canvas, 'EPPOS PHOTOBOOTH', pageW, y,
        fontSize: 24, bold: true, center: true);
    y += 32;
    _canvasText(canvas, 'Photobooth Experience', pageW, y,
        fontSize: 13, center: true);
    y += 22;

    // Tanggal
    final dateStr = DateFormat('dd/MM/yyyy  HH:mm').format(DateTime.now());
    _canvasText(canvas, dateStr, pageW, y, fontSize: 12, center: true);
    y += 18;

    // Garis separator
    canvas.drawRect(Rect.fromLTWH(pad, y, innerW, 2), blackPaint);
    y += 10;

    // === FOTO ===
    void drawPhoto(ui.Image? photo, Rect destRect) {
      if (photo != null) {
        final srcRect = Rect.fromLTWH(
            0, 0, photo.width.toDouble(), photo.height.toDouble());
        canvas.drawImageRect(
          photo,
          srcRect,
          destRect,
          Paint()..filterQuality = FilterQuality.medium,
        );
      } else {
        // Placeholder abu-abu jika foto tidak tersedia
        canvas.drawRect(
            destRect, Paint()..color = const Color(0xFFD1D5DB));
        _canvasText(canvas, 'FOTO', destRect.left + destRect.width / 2,
            destRect.top + destRect.height / 2 - 8,
            fontSize: 14, center: false);
      }
      // Border bingkai foto
      canvas.drawRect(destRect, borderPaint);
    }

    final p0 = decodedPhotos.isNotEmpty ? decodedPhotos[0] : null;
    final p1 =
        decodedPhotos.length > 1 ? decodedPhotos[1] : decodedPhotos.isNotEmpty ? decodedPhotos[0] : null;
    final p2 =
        decodedPhotos.length > 2 ? decodedPhotos[2] : decodedPhotos.isNotEmpty ? decodedPhotos[0] : null;
    final p3 =
        decodedPhotos.length > 3 ? decodedPhotos[3] : decodedPhotos.isNotEmpty ? decodedPhotos[0] : null;

    switch (template) {
      case PhotoboothTemplate.singleShot:
        final h = innerW / 1.25;
        drawPhoto(p0, Rect.fromLTWH(pad, y, innerW, h));
        y += h;
        break;

      case PhotoboothTemplate.classicStrip:
        final frameH = innerW / 1.35;
        for (int i = 0; i < 4; i++) {
          final ph = [p0, p1, p2, p3][i];
          drawPhoto(ph, Rect.fromLTWH(pad, y, innerW, frameH));
          y += frameH + 12;
        }
        y -= 12;
        break;

      case PhotoboothTemplate.squareGrid:
        final cellW = (innerW - 8) / 2;
        drawPhoto(p0, Rect.fromLTWH(pad, y, cellW, cellW));
        drawPhoto(p1, Rect.fromLTWH(pad + cellW + 8, y, cellW, cellW));
        y += cellW + 8;
        drawPhoto(p2, Rect.fromLTWH(pad, y, cellW, cellW));
        drawPhoto(p3, Rect.fromLTWH(pad + cellW + 8, y, cellW, cellW));
        y += cellW;
        break;

      case PhotoboothTemplate.bentoStyle:
        final topH = innerW / 1.5;
        drawPhoto(p0, Rect.fromLTWH(pad, y, innerW, topH));
        y += topH + 8;
        final botW = (innerW - 8) / 2;
        final botH = botW;
        drawPhoto(p1, Rect.fromLTWH(pad, y, botW, botH));
        drawPhoto(p2, Rect.fromLTWH(pad + botW + 8, y, botW, botH));
        y += botH;
        break;
    }

    y += 12;
    // Garis separator bawah
    canvas.drawRect(Rect.fromLTWH(pad, y, innerW, 2), blackPaint);
    y += 12;

    // === FOOTER ===
    _canvasText(canvas, 'Thank you for playing!', pageW, y,
        fontSize: 13, center: true);
    y += 22;
    _canvasText(canvas, 'www.eppos.id', pageW, y, fontSize: 12, center: true);
    y += 28;
    // Garis bawah tebal
    canvas.drawRect(Rect.fromLTWH(0, y, pageW, 6), blackPaint);

    // 3. Export ke PNG
    final picture = recorder.endRecording();
    final uiImage = await picture.toImage(pageW.toInt(), totalH.toInt());
    final byteData =
        await uiImage.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  void _canvasText(
    Canvas canvas,
    String text,
    double x,
    double y, {
    double fontSize = 14,
    bool bold = false,
    bool center = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          color: const Color(0xFF000000),
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    );
    tp.layout(maxWidth: 384 - 32);
    final dx = center ? (x - tp.width) / 2 : 16.0;
    tp.paint(canvas, Offset(dx, y));
  }

  Future<void> _handlePrintProcess(PhotoboothProvider provider) async {
    if (_isPrinting) return;

    final printerService = provider.printerService;

    if (!printerService.isConnected) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              "Printer Bluetooth belum terhubung! Silakan hubungkan printer di Pengaturan.",
            ),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            action: SnackBarAction(
              label: "PENGATURAN",
              textColor: Colors.white,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PrinterSettingsScreen(),
                  ),
                );
              },
            ),
          ),
        );
      }
      return;
    }

    setState(() => _isPrinting = true);
    _ejectionController.forward(from: 0.0);
    PrinterAudioService.playPrinterSound();

    try {
      // Render nota langsung via Canvas — foto sudah di-pre-decode sebelum export
      final imageBytes = await _buildReceiptBitmap(
        provider.capturedPhotos,
        provider.selectedTemplate,
      );

      if (imageBytes == null || imageBytes.isEmpty) {
        if (mounted) {
          setState(() => _isPrinting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Gagal render gambar nota cetak.")),
          );
        }
        return;
      }

      // Kirim ke printer thermal
      final success = await printerService.printReceiptImage(imageBytes);

      if (!mounted) return;
      setState(() => _isPrinting = false);

      if (success) {
        await provider.saveStripToGalleryAndHistory(
          stripImageBytes: imageBytes,
        );

        final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
        final downloadUrl = await CloudStorageService.uploadPhotoStrip(
          imageBytes: imageBytes,
          sessionId: sessionId,
        );

        if (!mounted) return;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SuccessScreen(
              sessionId: sessionId,
              downloadUrl: downloadUrl,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              "Gagal mencetak ke printer Eppos. Pastikan printer menyala dan terhubung.",
            ),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPrinting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Terjadi kesalahan saat mencetak: $e"),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PhotoboothProvider>(context);
    const scaffoldBgColor = Color(0xFFF4F4F5);

    final photosToRender = provider.capturedPhotos;

    return Scaffold(
      backgroundColor: scaffoldBgColor,
      body: Stack(
        children: [
          Column(
            children: [
              // 1. Custom Top Header Bar
              _CustomHeader(
                onBackTap: () => Navigator.pop(context),
              ),

              // 2. Skeuomorphic Printer Slot & Rolling Receipt (Stack Area)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Stack(
                    children: [
                      // Bottom Layer: Scrollable Receipt Paper (Wrapped in Screenshot & Ejection Animation)
                      Positioned.fill(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.only(top: 24, bottom: 24),
                          child: Center(
                            child: SlideTransition(
                              position: _slideAnimation,
                              child: FadeTransition(
                                opacity: _fadeAnimation,
                                child: Screenshot(
                                  controller: _screenshotController,
                                  child: _ThermalReceiptPaper(
                                    photoUrls: photosToRender,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Top Layer: Fixed Metallic Printer Machine Slot
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: _PrinterSlotMachinePart(
                            isPrinting: _isPrinting,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 3. Bottom Sticky Action Area
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                  decoration: BoxDecoration(
                    color: scaffoldBgColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Instruction Text
                      Text(
                        "Tap on the photo that needs to be retaken",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF4B5563),
                        ),
                      ),

                      const Gap(16),

                      // Flat Primary Print Button ("PRINT KE EPPOS (1 KOPI)")
                      GestureDetector(
                        onTap: _isPrinting
                            ? null
                            : () => _handlePrintProcess(provider),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF16A34A), // Rich green
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF16A34A)
                                    .withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: _isPrinting
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const Gap(10),
                                      Text(
                                        "MENCETAK...",
                                        style: GoogleFonts.inter(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  )
                                : Text(
                                    "PRINT KE EPPOS (${provider.copies} KOPI)",
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 1. CUSTOM TOP HEADER BAR
// ==========================================
class _CustomHeader extends StatelessWidget {
  final VoidCallback onBackTap;

  const _CustomHeader({required this.onBackTap});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Left: Back Chevron Icon
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Color(0xFF111827),
                size: 18,
              ),
              onPressed: onBackTap,
            ),

            // Center: Title "PHOTO BOOTH"
            Text(
              "PHOTO BOOTH",
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF111827),
                letterSpacing: 2.0,
              ),
            ),

            // Right: Empty Spacer for Center Balance
            const SizedBox(width: 18),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 2. SKEUOMORPHIC METALLIC PRINTER SLOT
// ==========================================
class _PrinterSlotMachinePart extends StatelessWidget {
  final bool isPrinting;

  const _PrinterSlotMachinePart({this.isPrinting = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 290,
      height: 40,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9999), // Metallic pill frame
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF4B5563),
            Color(0xFF9CA3AF),
            Color(0xFFE5E7EB),
            Color(0xFF9CA3AF),
            Color(0xFF374151),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        // Inner Dark Slit Hole with LED Indicator
        child: Container(
          width: 264,
          height: 20,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF18181B), // Dark slit
            borderRadius: BorderRadius.circular(9999),
            border: Border.all(
              color: Colors.black,
              width: 1.5,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black,
                blurRadius: 4,
                spreadRadius: -1,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left Glowing Green Power LED
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isPrinting
                      ? const Color(0xFF4ADE80)
                      : const Color(0xFF16A34A),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4ADE80).withValues(alpha: isPrinting ? 0.9 : 0.4),
                      blurRadius: isPrinting ? 8 : 4,
                      spreadRadius: isPrinting ? 2 : 0,
                    ),
                  ],
                ),
              ),
              const Expanded(child: SizedBox()),
              // Right Activity LED
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isPrinting
                      ? const Color(0xFFFACC15)
                      : const Color(0xFF52525B),
                  boxShadow: isPrinting
                      ? [
                          BoxShadow(
                            color: const Color(0xFFFACC15).withValues(alpha: 0.8),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 3. THERMAL RECEIPT PAPER (ROLLING OUT)
// ==========================================
class _ThermalReceiptPaper extends StatelessWidget {
  final List<String> photoUrls;

  const _ThermalReceiptPaper({
    required this.photoUrls,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.white, // Pure white receipt paper
        borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const Gap(28), // Spacing below printer slit

          // Receipt Monospace Header
          Text(
            "EPPOS BOOTH",
            style: GoogleFonts.jetBrainsMono(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF18181B),
              letterSpacing: 2.0,
            ),
          ),
          const Gap(4),
          Text(
            DateFormat("EEE, MMM d, yyyy").format(DateTime.now()).toUpperCase(),
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF3F3F46),
              letterSpacing: 1.2,
            ),
          ),

          const Gap(14),

          // Dashed Horizontal Line Divider
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: List.generate(
                22,
                (index) => Expanded(
                  child: Container(
                    height: 1.5,
                    color: index % 2 == 0
                        ? const Color(0xFFD4D4D8)
                        : Colors.transparent,
                  ),
                ),
              ),
            ),
          ),

          const Gap(16),

          // Dynamic Photo Layout based on selected canvas template (Classic Strip, Square Grid, Bento)
          Consumer<PhotoboothProvider>(
            builder: (context, provider, child) {
              final template = provider.selectedTemplate;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildPhotoLayout(context, template, photoUrls),
              );
            },
          ),

          const Gap(24),


          // 8-Bit Pixelated Logo & Footer
          const _PixelatedLogo(),

          const Gap(12),

          Text(
            "Thank you for playing!",
            style: GoogleFonts.jetBrainsMono(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF3F3F46),
            ),
          ),

          const Gap(28),
        ],
      ),
    );
  }

  Widget _buildPhotoLayout(
      BuildContext context, PhotoboothTemplate template, List<String> urls) {
    if (urls.isEmpty) return const SizedBox.shrink();

    switch (template) {
      case PhotoboothTemplate.squareGrid:
        // Layout 2x2 Square Grid
        return Column(
          children: [
            Row(
              children: [
                Expanded(child: _buildSinglePhotoFrame(urls[0 % urls.length], aspectRatio: 1.0)),
                const Gap(8),
                Expanded(child: _buildSinglePhotoFrame(urls[1 % urls.length], aspectRatio: 1.0)),
              ],
            ),
            const Gap(8),
            Row(
              children: [
                Expanded(child: _buildSinglePhotoFrame(urls[2 % urls.length], aspectRatio: 1.0)),
                const Gap(8),
                Expanded(child: _buildSinglePhotoFrame(urls[3 % urls.length], aspectRatio: 1.0)),
              ],
            ),
          ],
        );

      case PhotoboothTemplate.bentoStyle:
        // Layout Bento 3 foto (1 foto besar di atas + 2 foto bersampingan di bawah)
        return Column(
          children: [
            _buildSinglePhotoFrame(urls[0 % urls.length], aspectRatio: 1.5),
            const Gap(8),
            Row(
              children: [
                Expanded(child: _buildSinglePhotoFrame(urls[1 % urls.length], aspectRatio: 1.0)),
                const Gap(8),
                Expanded(child: _buildSinglePhotoFrame(urls[2 % urls.length], aspectRatio: 1.0)),
              ],
            ),
          ],
        );

      case PhotoboothTemplate.singleShot:
        // Layout Single Shot: 1 foto tunggal berukuran besar & jernih
        return Column(
          children: [
            _buildSinglePhotoFrame(
              urls.isNotEmpty ? urls[0] : "",
              aspectRatio: 1.25,
              isLast: true,
            ),
          ],
        );

      case PhotoboothTemplate.classicStrip:
        // Layout Klasik 4 foto vertical strip


        return Column(
          children: List.generate(
            4,
            (index) {
              final path = urls[index % urls.length];
              final isLast = index == 3;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildSinglePhotoFrame(path, aspectRatio: 1.35, isLast: isLast),
              );
            },
          ),
        );
    }
  }

  Widget _buildSinglePhotoFrame(String path, {double aspectRatio = 1.35, bool isLast = false}) {
    if (path.isEmpty) return _buildErrorPlaceholder();

    final isUrl = path.startsWith("http");
    Uint8List? rawBytes;

    if (!isUrl) {
      final file = File(path);
      if (file.existsSync()) {
        try {
          rawBytes = file.readAsBytesSync();
        } catch (e) {
          debugPrint('[SinglePhotoFrame] readAsBytesSync error: $e');
        }
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: const Color(0xFF18181B),
          width: 3.5, // Thick raw thermal frame border
        ),
      ),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: aspectRatio,
            child: (rawBytes != null && rawBytes.isNotEmpty)
                ? Image.memory(
                    rawBytes,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _buildErrorPlaceholder(),
                  )
                : (isUrl
                    ? Image.network(
                        path,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _buildErrorPlaceholder(),
                      )
                    : Image.file(
                        File(path),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _buildErrorPlaceholder(),
                      )),
          ),
          if (isLast)
            Container(
              width: double.infinity,
              height: 28,
              color: const Color(0xFF18181B),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorPlaceholder() {
    return Container(
      color: const Color(0xFFE2E8F0),
      child: const Center(
        child: Icon(
          Icons.image_outlined,
          color: Color(0xFF64748B),
          size: 32,
        ),
      ),
    );
  }
}

// ==========================================
// 4. PIXELATED 8-BIT LOGO GRAPHIC
// ==========================================
class _PixelatedLogo extends StatelessWidget {
  const _PixelatedLogo();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      "assets/images/logo.png",
      height: 44,
      fit: BoxFit.contain,
    );
  }
}
