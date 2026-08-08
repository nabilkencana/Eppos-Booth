import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class ThermalPhotoStrip extends StatelessWidget {
  final List<String> photoUrls;
  final String title;
  final String dateString;
  final String filterName;
  final bool isAutoBurst;

  const ThermalPhotoStrip({
    super.key,
    this.photoUrls = const [],
    this.title = "EPPOS PHOTOBOOTH",
    this.dateString = "2026.08.08 - 18:12",
    this.filterName = "MONO ARCADE",
    this.isAutoBurst = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: AppColors.thermalTicketBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header / Monospace Brand
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.print_rounded, size: 14, color: AppColors.thermalInk),
                    const SizedBox(width: 6),
                    Text(
                      "=== $title ===",
                      style: AppTheme.thermalTextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  dateString,
                  style: AppTheme.thermalTextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (isAutoBurst) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.thermalInk, width: 1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Text(
                      "[ AUTO-BURST 4x ]",
                      style: AppTheme.thermalTextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                // Perforated divider line
                Row(
                  children: List.generate(
                    20,
                    (index) => Expanded(
                      child: Container(
                        height: 1,
                        color: index % 2 == 0 ? AppColors.textMuted : Colors.transparent,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Photo Frames
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: List.generate(
                3,
                (index) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  height: 140,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.thermalInk.withValues(alpha: 0.15)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: photoUrls.length > index
                        ? Image.network(
                            photoUrls[index],
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _buildPlaceholderPhoto(index),
                          )
                        : _buildPlaceholderPhoto(index),
                  ),
                ),
              ),
            ),
          ),

          // Receipt Footer & Barcode Simulation
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              children: [
                Text(
                  "FILTER: $filterName",
                  style: AppTheme.thermalTextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                // Simulated Barcode
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    36,
                    (index) => Container(
                      width: (index % 3 == 0) ? 3 : (index % 2 == 0 ? 2 : 1),
                      height: 28,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      color: AppColors.thermalInk,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "* THANK YOU FOR MAKING MEMORIES *",
                  style: AppTheme.thermalTextStyle(
                    fontSize: 9,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Scalloped / Perforated Bottom Edge
          ClipPath(
            clipper: ScallopClipper(),
            child: Container(
              height: 12,
              color: AppColors.thermalTicketBg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderPhoto(int index) {
    final colors = [
      const Color(0xFFE2E8F0),
      const Color(0xFFCBD5E1),
      const Color(0xFF94A3B8),
    ];
    final icons = [Icons.camera_alt_rounded, Icons.auto_awesome, Icons.favorite_rounded];

    return Container(
      color: colors[index % colors.length],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icons[index % icons.length], size: 28, color: AppColors.textSecondary),
            const SizedBox(height: 4),
            Text(
              "FRAME #${index + 1}",
              style: AppTheme.thermalTextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ScallopClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, 0);
    path.lineTo(size.width, 0);

    const int count = 20;
    final double step = size.width / count;

    for (int i = count; i >= 0; i--) {
      final double x = i * step;
      path.lineTo(x + (step / 2), size.height);
      path.lineTo(x, 0);
    }

    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
