import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/photobooth_provider.dart';
import 'camera_session_screen.dart';

class TemplateItemData {
  final String title;
  final String description;
  final Widget wireframe;

  const TemplateItemData({
    required this.title,
    required this.description,
    required this.wireframe,
  });
}

class TemplateSelectionScreen extends StatefulWidget {
  const TemplateSelectionScreen({super.key});

  @override
  State<TemplateSelectionScreen> createState() =>
      _TemplateSelectionScreenState();
}

class _TemplateSelectionScreenState extends State<TemplateSelectionScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    const scaffoldBgColor = Color(0xFFF4F4F5);

    final templates = [
      TemplateItemData(
        title: "Classic Strip",
        description: "4 foto berderet. Format photobooth klasik.",
        wireframe: _buildStripWireframe(),
      ),
      TemplateItemData(
        title: "Square Grid",
        description: "4 foto kotak. Cocok untuk kolase.",
        wireframe: _buildGridWireframe(),
      ),
      TemplateItemData(
        title: "Bento Style",
        description: "3 foto asimetris. Modern & dinamis.",
        wireframe: _buildBentoWireframe(),
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Column(
            children: [
              // 1. Custom Top Header (Step 1 of 3 + Thick Line)
              _CustomTopHeader(
                onBackTap: () => Navigator.pop(context),
              ),

              // 2. Scrollable Body (Hero Text + Template Cards)
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    children: [
                      const Gap(28),

                      // Hero Text Section
                      Text(
                        "Pilih Kanvas",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF111827),
                          letterSpacing: -0.4,
                        ),
                      ),
                      const Gap(8),
                      Text(
                        "Pilih tata letak foto untuk cetakan nota Anda.",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF4B5563),
                        ),
                      ),

                      const Gap(32),

                      // Template Cards List
                      ...List.generate(
                        templates.length,
                        (index) => TemplateCard(
                          data: templates[index],
                          isSelected: _selectedIndex == index,
                          onTap: () => setState(() => _selectedIndex = index),
                        ),
                      ),

                      const Gap(24),
                    ],
                  ),
                ),
              ),

              // 3. Bottom Sticky Action Section & Scalloped Receipt Divider
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Primary CTA Button ("LANJUT KE KAMERA")
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: Consumer<PhotoboothProvider>(
                      builder: (context, provider, child) {
                        return _NextButton(
                          label: "LANJUT KE KAMERA",
                          onPressed: () {
                            final selectedEnum = PhotoboothTemplate.values[_selectedIndex];
                            provider.setSelectedTemplate(selectedEnum);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const CameraSessionScreen(),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),

                  // Scalloped Torn Receipt Perforated Edge
                  const _ScallopedEdge(
                    paperColor: Colors.white,
                    backgroundColor: scaffoldBgColor,
                    height: 16,
                  ),

                  // Bottom Grey Footing
                  Container(
                    width: double.infinity,
                    height: 48,
                    color: scaffoldBgColor,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Wireframe Layout Helpers ---
  static Widget _buildStripWireframe() {
    return Container(
      width: 56,
      height: 76,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1.2),
      ),
      child: Column(
        children: List.generate(
          4,
          (index) => Expanded(
            child: Container(
              margin: EdgeInsets.only(bottom: index < 3 ? 3.0 : 0),
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Widget _buildGridWireframe() {
    return Container(
      width: 56,
      height: 76,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1.2),
      ),
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Gap(3),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Gap(3),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Gap(3),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildBentoWireframe() {
    return Container(
      width: 56,
      height: 76,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1.2),
      ),
      child: Column(
        children: [
          Expanded(
            flex: 3,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Gap(3),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Gap(3),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 1. CUSTOM TOP HEADER
// ==========================================
class _CustomTopHeader extends StatelessWidget {
  final VoidCallback onBackTap;

  const _CustomTopHeader({required this.onBackTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Back Arrow
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

                // Monospace STEP 1 OF 3
                Text(
                  "STEP 1 OF 3",
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF111827),
                    letterSpacing: 2.0,
                  ),
                ),

                // Balance Spacer
                const SizedBox(width: 24),
              ],
            ),
          ),
        ),

        // Thick Dark Divider Line
        Container(
          height: 4,
          width: double.infinity,
          color: const Color(0xFF27272A),
        ),
      ],
    );
  }
}

// ==========================================
// 2. TEMPLATE CARD WIDGET
// ==========================================
class TemplateCard extends StatelessWidget {
  final TemplateItemData data;
  final bool isSelected;
  final VoidCallback onTap;

  const TemplateCard({
    super.key,
    required this.data,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF0FDF4) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF16A34A)
                : const Color(0xFFE5E7EB),
            width: isSelected ? 2.0 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Wireframe Icon
            data.wireframe,

            const Gap(16),

            // Title & Description
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.title,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  const Gap(4),
                  Text(
                    data.description,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF4B5563),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),

            // Checkmark Circle Icon (Selected State)
            if (isSelected) ...[
              const Gap(8),
              const Icon(
                Icons.check_circle,
                color: Color(0xFF16A34A),
                size: 24,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 3. TACTILE 3D NEXT BUTTON
// ==========================================
class _NextButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;

  const _NextButton({
    required this.label,
    required this.onPressed,
  });

  @override
  State<_NextButton> createState() => _NextButtonState();
}

class _NextButtonState extends State<_NextButton> {
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
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        transform: Matrix4.translationValues(0, _isPressed ? 4 : 0, 0),
        decoration: BoxDecoration(
          color: const Color(0xFF16A34A),
          borderRadius: BorderRadius.circular(9999),
          border: Border.all(
            color: const Color(0xFF14532D),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF14532D),
              offset: Offset(0, _isPressed ? 0 : 4),
              blurRadius: 0,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              widget.label,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
            const Gap(10),
            const Icon(
              Icons.camera_alt_outlined,
              color: Colors.white,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 4. SCALLOPED DIVIDER
// ==========================================
class _ScallopedEdge extends StatelessWidget {
  final Color paperColor;
  final Color backgroundColor;
  final double height;

  const _ScallopedEdge({
    required this.paperColor,
    required this.backgroundColor,
    this.height = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: CustomPaint(
        painter: _ScallopedEdgePainter(
          paperColor: paperColor,
          backgroundColor: backgroundColor,
        ),
      ),
    );
  }
}

class _ScallopedEdgePainter extends CustomPainter {
  final Color paperColor;
  final Color backgroundColor;

  const _ScallopedEdgePainter({
    required this.paperColor,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = backgroundColor;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final paperPaint = Paint()
      ..color = paperColor
      ..style = PaintingStyle.fill;

    const double scallopRadius = 8.0;
    final int count = (size.width / (scallopRadius * 2)).floor();
    final double actualRadius = size.width / (count * 2);

    final path = Path();
    path.moveTo(0, 0);

    for (int i = 0; i < count; i++) {
      final x = i * (actualRadius * 2);
      path.arcToPoint(
        Offset(x + actualRadius * 2, 0),
        radius: Radius.circular(actualRadius),
        clockwise: false,
      );
    }

    path.lineTo(size.width, 0);
    path.lineTo(0, 0);
    path.close();

    canvas.drawPath(path, paperPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
