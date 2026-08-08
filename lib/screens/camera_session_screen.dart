import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/photobooth_provider.dart';
import 'review_screen.dart';

class CameraSessionScreen extends StatefulWidget {
  const CameraSessionScreen({super.key});

  @override
  State<CameraSessionScreen> createState() => _CameraSessionScreenState();
}

class _CameraSessionScreenState extends State<CameraSessionScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _flashController;
  late Animation<double> _flashAnimation;

  bool _isCapturing = false;
  int _currentCountdown = 0;
  int _currentPhotoIndex = 0;

  @override
  void initState() {
    super.initState();
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _flashAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _flashController, curve: Curves.easeOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => _initCamera());
  }

  Future<void> _initCamera() async {
    if (!mounted) return;
    final svc = context.read<PhotoboothProvider>().cameraService;
    // iOS butuh sedikit delay setelah frame pertama render
    // sebelum membuka kamera — mencegah freeze/deadlock
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    await svc.initializeCamera();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _flashController.dispose();
    super.dispose();
  }

  void _triggerFlash() {
    _flashController.forward(from: 0.0).then((_) => _flashController.reverse());
  }

  Future<void> _startAutoBurstSession() async {
    if (_isCapturing) return;

    final provider = context.read<PhotoboothProvider>();
    final svc = provider.cameraService;

    // ─── GUARD: jangan mulai tanpa kamera ───────────────────
    if (!svc.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF18181B),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          content: Row(
            children: [
              const Icon(Icons.camera_alt_outlined, color: Color(0xFF4ADE80)),
              const Gap(10),
              Expanded(
                child: Text(
                  "Kamera belum terhubung. Tap 'Hubungkan Kamera' terlebih dahulu.",
                  style: GoogleFonts.inter(
                      color: Colors.white, fontSize: 13),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }
    // ─────────────────────────────────────────────────────────

    final targetCount = provider.selectedTemplate.defaultFrameCount;

    setState(() {
      _isCapturing = true;
      _currentPhotoIndex = 0;
      _currentCountdown = 0;
    });

    provider.clearCapturedPhotos();

    for (int i = 0; i < targetCount; i++) {
      if (!mounted) break;

      setState(() => _currentPhotoIndex = i + 1);

      // Countdown 3 → 2 → 1
      for (int count = 3; count > 0; count--) {
        if (!mounted) break;
        setState(() => _currentCountdown = count);
        await Future.delayed(const Duration(seconds: 1));
      }

      if (!mounted) break;
      setState(() => _currentCountdown = 0);

      _triggerFlash();
      final file = await svc.takePicture();
      if (file != null) provider.addCapturedPhoto(file.path);

      await Future.delayed(const Duration(milliseconds: 400));
    }

    if (!mounted) return;
    setState(() => _isCapturing = false);

    if (provider.capturedPhotos.isEmpty) {
      // Tidak ada foto berhasil diambil — tampilkan error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          content: Text("Gagal mengambil foto. Coba lagi.",
              style: GoogleFonts.inter(color: Colors.white)),
        ),
      );
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ReviewScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PhotoboothProvider>();
    final svc = provider.cameraService;
    final targetCount = provider.selectedTemplate.defaultFrameCount;
    const bg = Color(0xFFF4F4F5);

    final badgeText = _isCapturing
        ? "Foto $_currentPhotoIndex / $targetCount"
        : "Auto burst";

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          Column(
            children: [
              // ── Header ────────────────────────────────────────
              _TopHeader(
                badgeText: badgeText,
                isCapturing: _isCapturing,
                hasManyLenses: svc.cameraCount > 1,
                onToggleCamera: () async {
                  if (!_isCapturing) {
                    await svc.switchCamera();
                    if (mounted) setState(() {});
                  }
                },
                onBackTap: () {
                  if (!_isCapturing) Navigator.pop(context);
                },
              ),

              // ── Viewfinder ────────────────────────────────────
              Expanded(
                child: _CameraViewfinder(
                  svc: svc,
                  countdown: _currentCountdown,
                  isCapturing: _isCapturing,
                  onRetry: () async {
                    await svc.initializeCamera(forceReinit: true);
                    if (mounted) setState(() {});
                  },
                ),
              ),

              // ── Scalloped edge ────────────────────────────────
              const _ScallopedEdge(
                paperColor: Colors.white,
                backgroundColor: bg,
                height: 16,
              ),

              // ── Shutter area ──────────────────────────────────
              Container(
                width: double.infinity,
                color: bg,
                padding: const EdgeInsets.symmetric(vertical: 36),
                child: Center(
                  child: _ShutterButton(
                    isReady: svc.isInitialized && !_isCapturing,
                    isLoading: _isCapturing,
                    onPressed: _startAutoBurstSession,
                  ),
                ),
              ),
            ],
          ),

          // ── Flash overlay ─────────────────────────────────────
          AnimatedBuilder(
            animation: _flashAnimation,
            builder: (_, _) => IgnorePointer(
              child: Container(
                color: Colors.white.withValues(alpha: _flashAnimation.value),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  HEADER
// ══════════════════════════════════════════════════════════════
class _TopHeader extends StatelessWidget {
  final String badgeText;
  final bool isCapturing;
  final bool hasManyLenses;
  final VoidCallback onToggleCamera;
  final VoidCallback onBackTap;

  const _TopHeader({
    required this.badgeText,
    required this.isCapturing,
    required this.hasManyLenses,
    required this.onToggleCamera,
    required this.onBackTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF18181B),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Back
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: isCapturing ? Colors.white30 : Colors.white,
                  size: 18,
                ),
                onPressed: isCapturing ? null : onBackTap,
              ),

              // Badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF4ADE80),
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Text(
                  badgeText,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF18181B),
                  ),
                ),
              ),

              // Flip camera (hanya jika ada lebih dari 1 kamera)
              if (hasManyLenses)
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(
                    Icons.flip_camera_ios_outlined,
                    color: isCapturing ? Colors.white30 : Colors.white,
                    size: 22,
                  ),
                  onPressed: isCapturing ? null : onToggleCamera,
                )
              else
                const SizedBox(width: 22),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  VIEWFINDER WIDGET
// ══════════════════════════════════════════════════════════════
class _CameraViewfinder extends StatelessWidget {
  final dynamic svc; // CameraService
  final int countdown;
  final bool isCapturing;
  final VoidCallback onRetry;

  const _CameraViewfinder({
    required this.svc,
    required this.countdown,
    required this.isCapturing,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Kamera live preview atau state placeholder
          // Stack(StackFit.expand) sudah memberikan bounded constraints,
          // jadi cukup SizedBox.expand — tidak perlu FittedBox.
          if (svc.isInitialized) ...[
            SizedBox.expand(
              child: CameraPreview(svc.controller!),
            ),
          ] else if (svc.isInitializing) ...[
            const _ViewfinderLoading(),
          ] else ...[
            _ViewfinderError(
              message: svc.errorMessage,
              onRetry: onRetry,
            ),
          ],

          // Countdown overlay
          if (isCapturing && countdown > 0)
            Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 120),
                transitionBuilder: (child, anim) =>
                    ScaleTransition(scale: anim, child: child),
                child: Text(
                  "$countdown",
                  key: ValueKey(countdown),
                  style: GoogleFonts.inter(
                    fontSize: 120,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF4ADE80),
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.6),
                        blurRadius: 24,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ViewfinderLoading extends StatelessWidget {
  const _ViewfinderLoading();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF18181B),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 44,
              height: 44,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Color(0xFF4ADE80),
              ),
            ),
            const Gap(16),
            Text(
              "Membuka kamera...",
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFA1A1AA),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ViewfinderError extends StatelessWidget {
  final String? message;
  final VoidCallback onRetry;

  const _ViewfinderError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF18181B),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.camera_alt_outlined,
                  size: 44,
                  color: Color(0xFF4ADE80),
                ),
              ),
              const Gap(16),
              Text(
                message ?? "Kamera belum terhubung",
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  height: 1.4,
                ),
              ),
              const Gap(8),
              Text(
                "Pastikan izin kamera sudah diberikan di Pengaturan HP.",
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF6B7280),
                  height: 1.4,
                ),
              ),
              const Gap(24),
              // IntrinsicWidth agar tombol tidak melebar penuh
              IntrinsicWidth(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9999),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 13),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(
                    "Hubungkan Kamera",
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  onPressed: onRetry,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  SCALLOPED EDGE
// ══════════════════════════════════════════════════════════════
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
        painter: _ScallopedPainter(
          paperColor: paperColor,
          bgColor: backgroundColor,
        ),
      ),
    );
  }
}

class _ScallopedPainter extends CustomPainter {
  final Color paperColor;
  final Color bgColor;

  const _ScallopedPainter(
      {required this.paperColor, required this.bgColor});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = bgColor);

    final paint = Paint()
      ..color = paperColor
      ..style = PaintingStyle.fill;

    const r = 8.0;
    final count = (size.width / (r * 2)).floor();
    final actualR = size.width / (count * 2);
    final path = Path()..moveTo(0, 0);

    for (int i = 0; i < count; i++) {
      final x = i * (actualR * 2);
      path.arcToPoint(
        Offset(x + actualR * 2, 0),
        radius: Radius.circular(actualR),
        clockwise: false,
      );
    }
    path.lineTo(size.width, 0);
    path.lineTo(0, 0);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ══════════════════════════════════════════════════════════════
//  SHUTTER BUTTON
//  • Abu-abu / disabled saat kamera belum siap
//  • Hijau saat siap
// ══════════════════════════════════════════════════════════════
class _ShutterButton extends StatefulWidget {
  final bool isReady;
  final bool isLoading;
  final VoidCallback onPressed;

  const _ShutterButton({
    required this.isReady,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  State<_ShutterButton> createState() => _ShutterButtonState();
}

class _ShutterButtonState extends State<_ShutterButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    // warna berdasarkan status
    final outerColor = widget.isReady
        ? const Color(0xFFD4FAE6) // hijau muda saat siap
        : const Color(0xFFE4E4E7); // abu saat belum siap
    final innerColor = widget.isReady
        ? const Color(0xFF16A34A) // emerald saat siap
        : const Color(0xFF9CA3AF); // abu saat belum siap

    return Tooltip(
      message: widget.isReady ? "Mulai sesi foto" : "Kamera belum terhubung",
      child: GestureDetector(
        onTapDown: widget.isReady && !widget.isLoading
            ? (_) => setState(() => _pressed = true)
            : null,
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.isReady && !widget.isLoading ? widget.onPressed : null,
        child: AnimatedScale(
          scale: _pressed ? 0.90 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: outerColor,
              boxShadow: widget.isReady
                  ? [
                      BoxShadow(
                        color: const Color(0xFF16A34A).withValues(alpha: 0.3),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: widget.isLoading
                  ? const SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: Color(0xFF16A34A),
                      ),
                    )
                  : Container(
                      width: 66,
                      height: 66,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: innerColor,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// Public alias for ScallopedEdge
class ScallopedEdge extends StatelessWidget {
  final Color paperColor;
  final Color backgroundColor;
  final double height;

  const ScallopedEdge({
    super.key,
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
        painter: _ScallopedPainter(
          paperColor: paperColor,
          bgColor: backgroundColor,
        ),
      ),
    );
  }
}
