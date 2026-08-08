import 'dart:io';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/photobooth_provider.dart';
import 'camera_session_screen.dart';
import 'strip_preview_screen.dart';

class ReviewScreen extends StatelessWidget {
  const ReviewScreen({super.key});

  // Grayscale ColorFilter matrix for 1-bit thermal print effect
  static const ColorFilter _grayscaleFilter = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0,      0,      0,      1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    const scaffoldBgColor = Color(0xFFE5E7EB); // Light grayish-off-white

    return Consumer<PhotoboothProvider>(
      builder: (context, provider, child) {
        final photos = provider.capturedPhotos;

        return Scaffold(
          backgroundColor: scaffoldBgColor,
          body: Stack(
            children: [
              Column(
                children: [
                  // 1. Custom Top Header (Review Foto + Dynamic Count Badge)
                  _CustomHeader(
                    countText: "${photos.length}/${photos.length}",
                    onBackTap: () => Navigator.pop(context),
                  ),

                  const Gap(12),

                  // 2. Floating Drag Tooltip ("Tahan & geser...")
                  const _FloatingDragTooltip(),

                  const Gap(16),

                  // 3. Main Thermal Photo Strip Mockup Canvas with Reorderable List
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Center(
                        child: _ThermalStripCanvas(
                          photoPaths: photos,
                          onReorder: (oldIndex, newIndex) {
                            if (provider.capturedPhotos.isNotEmpty) {
                              provider.reorderPhotos(oldIndex, newIndex);
                            }
                          },
                        ),
                      ),
                    ),
                  ),

                  // 4. Sticky Bottom 3D Action Buttons Row
                  SafeArea(
                    top: false,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                      decoration: BoxDecoration(
                        color: scaffoldBgColor,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, -4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Button 1: "Ambil Ulang" (Retake)
                          Expanded(
                            child: ArcadeButton(
                              label: "Ambil Ulang",
                              icon: Icons.refresh_rounded,
                              backgroundColor: const Color(0xFFF4F5F0),
                              borderColor: const Color(0xFF27272A),
                              bottomBorderColor: const Color(0xFF27272A),
                              textColor: const Color(0xFF18181B),
                              isVertical: true,
                              onPressed: () {
                                provider.clearCapturedPhotos();
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const CameraSessionScreen(),
                                  ),
                                );
                              },
                            ),
                          ),

                          const Gap(14),

                          // Button 2: "LANJUT CETAK" (Print)
                          Expanded(
                            child: ArcadeButton(
                              label: "LANJUT CETAK",
                              icon: Icons.print_outlined,
                              backgroundColor: const Color(0xFF16A34A),
                              borderColor: const Color(0xFF14532D),
                              bottomBorderColor: const Color(0xFF14532D),
                              textColor: Colors.white,
                              isVertical: false,
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const StripPreviewScreen(),
                                  ),
                                );
                              },
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
      },
    );
  }

  // Image rendering helper (supports File or URL with Grayscale filter)
  static Widget _buildGrayscaleImage(String path) {
    final isUrl = path.startsWith("http");

    Widget rawImage = isUrl
        ? Image.network(
            path,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _buildErrorBox(),
          )
        : Image.file(
            File(path),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _buildErrorBox(),
          );

    return ColorFiltered(
      colorFilter: _grayscaleFilter,
      child: rawImage,
    );
  }

  static Widget _buildErrorBox() {
    return Container(
      color: const Color(0xFFCBD5E1),
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
// 1. CUSTOM TOP HEADER
// ==========================================
class _CustomHeader extends StatelessWidget {
  final String countText;
  final VoidCallback onBackTap;

  const _CustomHeader({
    required this.countText,
    required this.onBackTap,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Left: Back Arrow
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(
                Icons.arrow_back,
                color: Color(0xFF111827),
                size: 24,
              ),
              onPressed: onBackTap,
            ),

            // Center: Title "Review Foto"
            Text(
              "Review Foto",
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF111827),
                letterSpacing: -0.3,
              ),
            ),

            // Right: Dynamic Status Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB), // Light grey badge
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                countText,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF4B5563),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 2. FLOATING TOOLTIP ("Tahan & geser...")
// ==========================================
class _FloatingDragTooltip extends StatelessWidget {
  const _FloatingDragTooltip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B), // Dark zinc background
        borderRadius: BorderRadius.circular(9999), // Pill shape
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.touch_app_outlined,
            color: Colors.white,
            size: 18,
          ),
          const Gap(8),
          Text(
            "Tahan & geser untuk mengubah urutan",
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 3. THERMAL STRIP CANVAS MOCKUP WITH REORDERABLE LIST
// ==========================================
class _ThermalStripCanvas extends StatelessWidget {
  final List<String> photoPaths;
  final void Function(int oldIndex, int newIndex) onReorder;

  const _ThermalStripCanvas({
    required this.photoPaths,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 270,
      decoration: BoxDecoration(
        color: Colors.white, // Pure white paper strip
        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          const Gap(20),

          // Receipt Monospace Header "BOOTH 01"
          Text(
            "BOOTH  01",
            style: GoogleFonts.jetBrainsMono(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF18181B),
              letterSpacing: 3.0,
            ),
          ),

          const Gap(12),

          // Dashed Divider Line
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
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

          // Reorderable Photo Frame List
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: photoPaths.length,
              onReorderItem: (oldIndex, newIndex) => onReorder(oldIndex, newIndex),
              itemBuilder: (context, index) {
                final path = photoPaths[index];
                return Container(
                  key: ValueKey(path + index.toString()),
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1FAE5), // Retro light green frame
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: const Color(0xFF18181B).withValues(alpha: 0.15),
                      width: 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: AspectRatio(
                      aspectRatio: 1.15,
                      child: ReviewScreen._buildGrayscaleImage(path),
                    ),
                  ),
                );
              },
            ),
          ),

          const Gap(16),
        ],
      ),
    );
  }
}

// ==========================================
// 4. REUSABLE 3D ARCADE BUTTON WIDGET
// ==========================================
class ArcadeButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color borderColor;
  final Color bottomBorderColor;
  final Color textColor;
  final VoidCallback onPressed;
  final bool isVertical;

  const ArcadeButton({
    super.key,
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.borderColor,
    required this.bottomBorderColor,
    required this.textColor,
    required this.onPressed,
    this.isVertical = false,
  });

  @override
  State<ArcadeButton> createState() => _ArcadeButtonState();
}

class _ArcadeButtonState extends State<ArcadeButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        transform: Matrix4.translationValues(0, _isPressed ? 3 : 0, 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: widget.backgroundColor,
          borderRadius: BorderRadius.circular(12), // 12px rounded corners
          border: Border.all(
            color: widget.borderColor,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: widget.bottomBorderColor,
              offset: Offset(0, _isPressed ? 0 : 3.5),
              blurRadius: 0,
            ),
          ],
        ),
        child: widget.isVertical
            ? Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    widget.icon,
                    color: widget.textColor,
                    size: 20,
                  ),
                  const Gap(4),
                  Text(
                    widget.label,
                    style: GoogleFonts.inter(
                      color: widget.textColor,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.icon,
                    color: widget.textColor,
                    size: 20,
                  ),
                  const Gap(6),
                  Flexible(
                    child: Text(
                      widget.label,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: widget.textColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
