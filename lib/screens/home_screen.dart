import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/photobooth_provider.dart';
import 'printer_settings_screen.dart';
import 'template_selection_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentNavIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE5E7EB), // Light grayish-off-white (Zinc-200)
      body: Stack(
        children: [
          // IndexedStack preserves state across all 4 tab screens
          IndexedStack(
            index: _currentNavIndex,
            children: const [
              _HomeDashboardView(),
              _GalleryGridView(),
              _PrintHistoryView(),
              PrinterSettingsScreen(),
            ],
          ),

          // Floating Bottom Navigation Bar
          Positioned(
            left: 24,
            right: 24,
            bottom: 24,
            child: FloatingBottomNav(
              currentIndex: _currentNavIndex,
              onTap: (index) {
                setState(() {
                  _currentNavIndex = index;
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 1. HOME DASHBOARD TAB VIEW
// ==========================================
class _HomeDashboardView extends StatelessWidget {
  const _HomeDashboardView();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Custom Header at the top
        const _CustomHeader(),

        // Scrollable Body
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 110),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                // Hero Section (Headline, Subtitle, 3D Pill CTA)
                _HeroSection(),

                Gap(40),

                // Recent Prints Section Header & Cards
                _RecentPrintsSection(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ==========================================
// 2. GALLERY GRID TAB VIEW
// ==========================================
class _GalleryGridView extends StatelessWidget {
  const _GalleryGridView();

  @override
  Widget build(BuildContext context) {
    return Consumer<PhotoboothProvider>(
      builder: (context, provider, child) {
        final galleryPhotos = provider.allGalleryPhotos;

        return Column(
          children: [
            const _CustomHeader(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 110),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Galeri Foto",
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF18181B),
                      ),
                    ),
                    const Gap(8),
                    Text(
                      "Kumpulan cetakan digital photobooth Anda.",
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: const Color(0xFF71717A),
                      ),
                    ),
                    const Gap(24),

                    if (galleryPhotos.isEmpty)
                      const _EmptyDataCard(
                        icon: Icons.photo_library_outlined,
                        title: "Belum Ada Foto",
                        subtitle: "Mulai sesi photobooth baru untuk menyimpan foto ke galeri.",
                      )
                    else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.8,
                        ),
                        itemCount: galleryPhotos.length,
                        itemBuilder: (context, index) {
                          final path = galleryPhotos[index];
                          final isUrl = path.startsWith("http");

                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: isUrl
                                  ? Image.network(
                                      path,
                                      fit: BoxFit.cover,
                                    )
                                  : Image.file(
                                      File(path),
                                      fit: BoxFit.cover,
                                    ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ==========================================
// 3. PRINT HISTORY TAB VIEW
// ==========================================
class _PrintHistoryView extends StatelessWidget {
  const _PrintHistoryView();

  @override
  Widget build(BuildContext context) {
    return Consumer<PhotoboothProvider>(
      builder: (context, provider, child) {
        final history = provider.printHistory;

        return Column(
          children: [
            const _CustomHeader(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 110),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Riwayat Cetak",
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF18181B),
                      ),
                    ),
                    const Gap(8),
                    Text(
                      "Daftar sesi cetak thermal Eppos terbaru.",
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: const Color(0xFF71717A),
                      ),
                    ),
                    const Gap(24),

                    if (history.isEmpty)
                      const _EmptyDataCard(
                        icon: Icons.history_rounded,
                        title: "Belum Ada Riwayat Cetak",
                        subtitle: "Sesi cetak nota thermal yang berhasil akan muncul di sini.",
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: history.length,
                        separatorBuilder: (_, _) => const Gap(16),
                        itemBuilder: (context, index) {
                          final session = history[index];
                          final dateStr = DateFormat("d MMM yyyy - HH:mm")
                              .format(session.timestamp);
                          final coverPhoto = (session.stripImagePath != null && session.stripImagePath!.isNotEmpty)
                              ? session.stripImagePath!
                              : (session.photoPaths.isNotEmpty
                                  ? session.photoPaths.first
                                  : "");

                          return _RecentPrintCard(
                            title: session.title,
                            location: session.location,
                            date: dateStr,
                            photoCount: session.photoPaths.length,
                            imagePath: coverPhoto,
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ==========================================
// 4. CUSTOM TOP HEADER
// ==========================================
class _CustomHeader extends StatelessWidget {
  const _CustomHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4), // Faint mint green background
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: const Border(
          bottom: BorderSide(
            color: Color(0xFFDCFCE7),
            width: 1.0,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Center(
            child: Text(
              "EPPOS BOOTH",
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
                color: const Color(0xFF15803D), // Rich dark green
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 5. HERO SECTION
// ==========================================
class _HeroSection extends StatelessWidget {
  const _HeroSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Ready to make some memories?",
          style: GoogleFonts.inter(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: const Color(0xFF27272A),
            height: 1.25,
          ),
        ),
        const Gap(12),
        Text(
          "Abadikan momen seru bersama teman-temanmu dan cetak langsung dalam format struk thermal retro!",
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: const Color(0xFF71717A),
            height: 1.5,
          ),
        ),
        const Gap(28),
        const _HeroButton(),
      ],
    );
  }
}

// 3D Animated Arcade Hero CTA Button ("MULAI SESI BARU")
class _HeroButton extends StatefulWidget {
  const _HeroButton();

  @override
  State<_HeroButton> createState() => _HeroButtonState();
}

class _HeroButtonState extends State<_HeroButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const TemplateSelectionScreen(),
          ),
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        transform: Matrix4.translationValues(0, _isPressed ? 4 : 0, 0),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
        decoration: BoxDecoration(
          color: const Color(0xFF16A34A), // Rich green
          borderRadius: BorderRadius.circular(9999), // Pill shape
          border: Border.all(
            color: const Color(0xFF15803D),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF14532D), // Dark green bottom depth
              offset: Offset(0, _isPressed ? 0 : 4),
              blurRadius: 0,
            ),
            if (!_isPressed)
              BoxShadow(
                color: const Color(0xFF16A34A).withValues(alpha: 0.3),
                blurRadius: 16,
                spreadRadius: 0,
                offset: const Offset(0, 6),
              ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const _ApertureShutterIcon(),
            const Gap(12),
            Text(
              "MULAI SESI BARU",
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom Aperture Camera Shutter Icon
class _ApertureShutterIcon extends StatelessWidget {
  const _ApertureShutterIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 22,
      child: CustomPaint(
        painter: _AperturePainter(),
      ),
    );
  }
}

class _AperturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    canvas.drawCircle(center, radius - 1, paint);

    for (int i = 0; i < 6; i++) {
      final angle = (i * 60) * (3.14159 / 180);
      final x1 = center.dx + (radius - 1) * cos(angle);
      final y1 = center.dy + (radius - 1) * sin(angle);
      final innerAngle = angle + (40 * (3.14159 / 180));
      final x2 = center.dx + (radius * 0.45) * cos(innerAngle);
      final y2 = center.dy + (radius * 0.45) * sin(innerAngle);
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ==========================================
// 6. RECENT PRINTS SECTION (DYNAMIC PROVIDER DATA)
// ==========================================
class _RecentPrintsSection extends StatelessWidget {
  const _RecentPrintsSection();

  @override
  Widget build(BuildContext context) {
    return Consumer<PhotoboothProvider>(
      builder: (context, provider, child) {
        final history = provider.printHistory;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Cetakan Terakhir",
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF27272A),
                  ),
                ),
              ],
            ),
            const Gap(16),

            if (history.isEmpty)
              const _EmptyDataCard(
                icon: Icons.print_outlined,
                title: "Belum Ada Cetakan",
                subtitle:
                    "Tekan 'MULAI SESI BARU' untuk membuat foto struk thermal pertama Anda!",
              )
            else
              Column(
                children: List.generate(
                  history.length.clamp(0, 3), // Show top 3 recent sessions
                  (index) {
                    final session = history[index];
                    final dateStr = DateFormat("d MMM yyyy - HH:mm")
                        .format(session.timestamp);
                    final coverPhoto = (session.stripImagePath != null && session.stripImagePath!.isNotEmpty)
                        ? session.stripImagePath!
                        : (session.photoPaths.isNotEmpty
                            ? session.photoPaths.first
                            : "");

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _RecentPrintCard(
                        title: session.title,
                        location: session.location,
                        date: dateStr,
                        photoCount: session.photoPaths.length,
                        imagePath: coverPhoto,
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

class _RecentPrintCard extends StatelessWidget {
  final String title;
  final String location;
  final String date;
  final int photoCount;
  final String imagePath;

  const _RecentPrintCard({
    required this.title,
    required this.location,
    required this.date,
    required this.photoCount,
    required this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    final isUrl = imagePath.startsWith("http");

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: 80,
              height: 96,
              child: imagePath.isEmpty
                  ? Container(
                      color: const Color(0xFFF4F4F5),
                      child: const Icon(
                        Icons.photo_outlined,
                        color: Color(0xFFA1A1AA),
                      ),
                    )
                  : (isUrl
                      ? Image.network(
                          imagePath,
                          fit: BoxFit.cover,
                        )
                      : Image.file(
                          File(imagePath),
                          fit: BoxFit.cover,
                        )),
            ),
          ),
          const Gap(16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF27272A),
                  ),
                ),
                const Gap(4),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 14,
                      color: Color(0xFF71717A),
                    ),
                    const Gap(4),
                    Text(
                      location,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF71717A),
                      ),
                    ),
                  ],
                ),
                const Gap(12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      date,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF71717A),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F4F5),
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      child: Text(
                        "$photoCount Foto",
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF3F3F46),
                        ),
                      ),
                    ),
                  ],
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
// 7. CLEAN EMPTY DATA CARD
// ==========================================
class _EmptyDataCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyDataCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFF4F4F5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 32,
              color: const Color(0xFF9CA3AF),
            ),
          ),
          const Gap(16),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF111827),
            ),
          ),
          const Gap(6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF6B7280),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 8. DYNAMIC FLOATING BOTTOM NAVIGATION BAR
// ==========================================
class FloatingBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const FloatingBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF4B5563), // Dark slate/grey pill background
        borderRadius: BorderRadius.circular(9999), // Perfectly pill shaped
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // 1. Home
          _buildNavItem(
            index: 0,
            icon: Icons.home_rounded,
          ),
          // 2. Grid / Gallery
          _buildNavItem(
            index: 1,
            icon: Icons.grid_view_rounded,
          ),
          // 3. History
          _buildNavItem(
            index: 2,
            icon: Icons.access_time_rounded,
          ),
          // 4. Settings
          _buildNavItem(
            index: 3,
            icon: Icons.settings_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
  }) {
    final isActive = currentIndex == index;

    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive ? const Color(0xFF16A34A) : Colors.transparent,
        ),
        child: Icon(
          icon,
          size: 24,
          color: isActive ? Colors.white : const Color(0xFFE5E7EB),
        ),
      ),
    );
  }
}
