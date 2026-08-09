import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'home_screen.dart';


class SuccessScreen extends StatefulWidget {
  final String? sessionId;
  final String? downloadUrl;

  const SuccessScreen({
    super.key,
    this.sessionId,
    this.downloadUrl,
  });

  @override
  State<SuccessScreen> createState() => _SuccessScreenState();
}

class _SuccessScreenState extends State<SuccessScreen> {
  Future<void> _openDownloadUrl() async {

    final targetUrl = (widget.downloadUrl != null &&
            widget.downloadUrl!.startsWith("http"))
        ? widget.downloadUrl!
        : "https://google.com";

    final uri = Uri.parse(targetUrl);
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        await Share.share("Unduh Foto Digital EPPOS Photobooth: $targetUrl");
      }
    } catch (e) {
      debugPrint('[SuccessScreen] launchUrl error: $e');
      try {
        await Share.share("Unduh Foto Digital EPPOS Photobooth: $targetUrl");
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    const scaffoldBgColor = Color(0xFFF2F5F0);

    final activeQrData = (widget.downloadUrl != null &&
            widget.downloadUrl!.startsWith("http"))
        ? widget.downloadUrl!
        : "https://google.com";

    return Scaffold(
      backgroundColor: scaffoldBgColor,
      body: Stack(
        children: [
          Column(
            children: [
              // 1. Custom Top Header (EPPOSBOOTH + Close Icon)
              _CustomHeader(
                onCloseTap: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                    (route) => false,
                  );
                },
              ),

              // 2. Hero Success Message & QR Card (Scrollable Body)
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const Gap(28),

                      // Layered Green Checkmark Icon
                      const _SuccessIcon(),

                      const Gap(20),

                      // Title & Subtitle
                      Text(
                        "Berhasil Dicetak!",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF111827),
                          letterSpacing: -0.4,
                        ),
                      ),
                      const Gap(8),
                      Text(
                        "Foto fisik Anda sedang keluar. Jangan\nlupa simpan versi digitalnya.",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF4B5563),
                          height: 1.5,
                        ),
                      ),

                      const Gap(32),

                      // QR Code Card
                      QRCard(
                        qrData: activeQrData,
                      ),

                      const Gap(24),
                    ],
                  ),
                ),
              ),

              // 3. Bottom Action Buttons
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Tombol UNDUH FOTO DIGITAL (Utama)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9999),
                          ),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.download_rounded, size: 20),
                        label: Text(
                          "UNDUH FOTO DIGITAL",
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                        onPressed: _openDownloadUrl,
                      ),

                      const Gap(12),

                      // Tombol KEMBALI KE BERANDA (Secondary)
                      GestureDetector(
                        onTap: () {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (_) => const HomeScreen()),
                            (route) => false,
                          );
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(9999),
                            border: Border.all(
                              color: const Color(0xFF9CA3AF),
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            "SELESAI & KEMBALI KE BERANDA",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: const Color(0xFF374151),
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
  final VoidCallback onCloseTap;

  const _CustomHeader({required this.onCloseTap});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.only(top: 16, left: 24, right: 24, bottom: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Left Empty Spacer for Center Balance
            const SizedBox(width: 24),

            // Center Logo + Title "EPPOSBOOTH"
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  "assets/images/logo.png",
                  height: 36,
                  fit: BoxFit.contain,
                ),
                const Gap(10),
                Text(
                  "EPPOSBOOTH",
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF111827),
                    letterSpacing: 2.0,
                  ),
                ),
              ],
            ),

            // Right Close Icon
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(
                Icons.close_rounded,
                color: Color(0xFF374151),
                size: 24,
              ),
              onPressed: onCloseTap,
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 2. LAYERED SUCCESS ICON
// ==========================================
class _SuccessIcon extends StatelessWidget {
  const _SuccessIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF0F763E), // Dark green outer ring
      ),
      child: Center(
        child: Container(
          width: 68,
          height: 68,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF16A34A), // Bright green inner circle
          ),
          child: const Icon(
            Icons.check_rounded,
            color: Colors.white,
            size: 38,
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 3. QR CODE CARD
// ==========================================
class QRCard extends StatelessWidget {
  final String qrData;

  const QRCard({
    super.key,
    required this.qrData,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.06),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // QR Code — latar putih murni, kontras maksimal, bisa discan
          Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFE5E7EB),
                width: 1.5,
              ),
            ),
            padding: const EdgeInsets.all(10),
            child: QrImageView(
              data: qrData,
              version: QrVersions.auto,
              errorCorrectionLevel: QrErrorCorrectLevel.H,
              size: 200,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Color(0xFF14532D),
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Color(0xFF111827),
              ),
            ),
          ),

          const Gap(16),

          // URL sesi (bisa disalin)
          Text(
            qrData,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10,
              color: const Color(0xFF9CA3AF),
              height: 1.4,
            ),
          ),

          const Gap(14),

          // Instruksi scan
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.qr_code_scanner_rounded,
                size: 16,
                color: Color(0xFF374151),
              ),
              const Gap(6),
              Text(
                "Scan dengan kamera HP Anda",
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1F2937),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
