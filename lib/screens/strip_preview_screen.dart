import 'dart:io';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:screenshot/screenshot.dart';
import '../providers/photobooth_provider.dart';
import '../services/cloud_storage_service.dart';
import 'printer_settings_screen.dart';
import 'success_screen.dart';

class StripPreviewScreen extends StatefulWidget {
  const StripPreviewScreen({super.key});

  @override
  State<StripPreviewScreen> createState() => _StripPreviewScreenState();
}

class _StripPreviewScreenState extends State<StripPreviewScreen> {
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _isPrinting = false;

  Future<void> _handlePrintProcess(PhotoboothProvider provider) async {
    if (_isPrinting) return;

    final printerService = provider.printerService;

    // GUARD: Matikan simulasi — wajib terhubung ke printer Bluetooth
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

    setState(() {
      _isPrinting = true;
    });

    try {
      // 1. Capture high-res receipt paper strip (pixelRatio: 2.0 cukup & cepat)
      final imageBytes = await _screenshotController.capture(
        pixelRatio: 2.0,
      );

      if (imageBytes == null) {
        if (mounted) {
          setState(() => _isPrinting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Gagal mengambil preview foto.")),
          );
        }
        return;
      }

      // 2. Real Bluetooth thermal print ke Eppos printer
      final success = await printerService.printReceiptImage(imageBytes);

      if (!mounted) return;

      setState(() {
        _isPrinting = false;
      });

      if (success) {
        // 1. Simpan strip ke galeri HP dan riwayat cetak
        await provider.saveStripToGalleryAndHistory(
          stripImageBytes: imageBytes,
        );

        // 2. Upload ke Firebase Storage (Cloud) untuk mendapatkan Public Download URL
        final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
        final downloadUrl = await CloudStorageService.uploadPhotoStrip(
          imageBytes: imageBytes,
          sessionId: sessionId,
        );

        if (!mounted) return;

        // 3. Navigasi ke Success Screen dengan URL unduh digital
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
        // Tampilkan pesan error dan tetap di preview screen
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
        setState(() {
          _isPrinting = false;
        });
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
                      // Bottom Layer: Scrollable Receipt Paper (Wrapped in Screenshot)
                      Positioned.fill(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.only(top: 24, bottom: 24),
                          child: Center(
                            child: Screenshot(
                              controller: _screenshotController,
                              child: _ThermalReceiptPaper(
                                photoUrls: photosToRender,
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
                          child: _PrinterSlotMachinePart(),
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
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 290,
      height: 38,
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
        // Inner Dark Slit Hole
        child: Container(
          width: 264,
          height: 18,
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

          // Column of 4 Raw Thermal Prints with Thick Black Borders
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: List.generate(
                4,
                (index) {
                  final path = photoUrls[index % photoUrls.length];
                  final isLast = index == 3;
                  final isUrl = path.startsWith("http");

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
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
                          aspectRatio: 1.35,
                          child: isUrl
                              ? Image.network(
                                  path,
                                  fit: BoxFit.cover,
                                  color: Colors.grey,
                                  colorBlendMode: BlendMode.saturation,
                                  errorBuilder: (_, _, _) => _buildErrorPlaceholder(),
                                )
                              : Image.file(
                                  File(path),
                                  fit: BoxFit.cover,
                                  color: Colors.grey,
                                  colorBlendMode: BlendMode.saturation,
                                  errorBuilder: (_, _, _) => _buildErrorPlaceholder(),
                                ),
                        ),
                        // Black footer strip on the last photo frame
                        if (isLast)
                          Container(
                            width: double.infinity,
                            height: 28,
                            color: const Color(0xFF18181B),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
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
    // 4x4 Grid representation of the 8-bit logo
    final gridPattern = [
      [1, 1, 0, 0],
      [1, 1, 1, 1],
      [1, 0, 1, 1],
      [1, 1, 1, 1],
    ];

    return SizedBox(
      width: 36,
      height: 36,
      child: Column(
        children: gridPattern.map((row) {
          return Expanded(
            child: Row(
              children: row.map((cell) {
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(0.8),
                    color: cell == 1
                        ? const Color(0xFF18181B)
                        : Colors.transparent,
                  ),
                );
              }).toList(),
            ),
          );
        }).toList(),
      ),
    );
  }
}
