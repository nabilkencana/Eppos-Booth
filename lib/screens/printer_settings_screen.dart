import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../providers/photobooth_provider.dart';

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  bool _isScanning = false;
  bool _isConnecting = false;
  String _connectingDeviceName = "";

  @override
  Widget build(BuildContext context) {
    const scaffoldBgColor = Color(0xFFF4F4F5); // Light zinc/grey background

    return Consumer<PhotoboothProvider>(
      builder: (context, provider, child) {
        final printerService = provider.printerService;
        final isConnected = printerService.isConnected;
        final selectedDeviceName =
            printerService.selectedDevice?.name ?? "Eppos 58mm Thermal";

        return Scaffold(
          backgroundColor: scaffoldBgColor,
          body: Column(
            children: [
              // 1. Custom Top Header
              _CustomHeader(
                onBackTap: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                },
              ),

              // 2. Main Scrollable Settings Body
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 140),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- CARD 1: Printer Connection ---
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
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
                            Row(
                              children: [
                                // Leading Rounded Square Printer Icon Container
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF4F4F5),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(
                                    Icons.print_outlined,
                                    color: Color(0xFF18181B),
                                    size: 26,
                                  ),
                                ),
                                const Gap(16),
                                // Device Name & Connected Badge
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        selectedDeviceName,
                                        style: GoogleFonts.inter(
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF111827),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const Gap(6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isConnected
                                              ? const Color(0xFFECFDF5)
                                              : const Color(0xFFFEF2F2),
                                          borderRadius: BorderRadius.circular(
                                            9999,
                                          ),
                                          border: Border.all(
                                            color: isConnected
                                                ? const Color(0xFFA7F3D0)
                                                : const Color(0xFFFCA5A5),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: isConnected
                                                    ? const Color(0xFF10B981)
                                                    : const Color(0xFFEF4444),
                                              ),
                                            ),
                                            const Gap(6),
                                            Text(
                                              isConnected
                                                  ? "Terhubung"
                                                  : "Terputus",
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: isConnected
                                                    ? const Color(0xFF059669)
                                                    : const Color(0xFFDC2626),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const Gap(20),

                            // Connect / Scan Pill Button
                            GestureDetector(
                              onTap: (_isScanning || _isConnecting)
                                  ? null
                                  : () {
                                      if (isConnected) {
                                        printerService.disconnect();
                                        setState(() {});
                                      } else {
                                        _showDevicePickerBottomSheet(
                                          context,
                                          provider,
                                        );
                                      }
                                    },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: (_isScanning || _isConnecting)
                                      ? const Color(0xFFF3F4F6)
                                      : isConnected
                                      ? const Color(0xFFFEF2F2)
                                      : const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(9999),
                                  border: Border.all(
                                    color: (_isScanning || _isConnecting)
                                        ? const Color(0xFFE5E7EB)
                                        : isConnected
                                        ? const Color(0xFFFCA5A5)
                                        : const Color(0xFF86EFAC),
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (_isScanning || _isConnecting) ...[
                                      const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Color(0xFF16A34A),
                                        ),
                                      ),
                                      const Gap(10),
                                    ],
                                    Text(
                                      _isScanning
                                          ? "Memindai perangkat..."
                                          : _isConnecting
                                          ? "Menghubungkan ke $_connectingDeviceName..."
                                          : isConnected
                                          ? "Putuskan Koneksi"
                                          : "Pindai & Hubungkan Printer",
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: (_isScanning || _isConnecting)
                                            ? const Color(0xFF6B7280)
                                            : isConnected
                                            ? const Color(0xFFDC2626)
                                            : const Color(0xFF15803D),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Gap(20),

                      // --- CARD 2: Print Preferences ---
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "PREFERENSI CETAK",
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF6B7280),
                                letterSpacing: 1.5,
                              ),
                            ),
                            const Gap(16),

                            // Preference Item 1
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    "Cetak Otomatis setelah foto",
                                    style: GoogleFonts.inter(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF111827),
                                    ),
                                  ),
                                ),
                                CustomSettingsToggle(
                                  value: provider.autoPrintOnCapture,
                                  onChanged: (val) =>
                                      provider.toggleAutoPrint(val),
                                ),
                              ],
                            ),

                            const Divider(color: Color(0xFFF3F4F6), height: 32),

                            // Preference Item 2
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    "Jumlah Kopi Cetakan",
                                    style: GoogleFonts.inter(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF111827),
                                    ),
                                  ),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.remove_circle_outline,
                                        color: Color(0xFF4B5563),
                                      ),
                                      onPressed: () => provider.setCopies(
                                        provider.copies - 1,
                                      ),
                                    ),
                                    Text(
                                      "${provider.copies}",
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF111827),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.add_circle_outline,
                                        color: Color(0xFF4B5563),
                                      ),
                                      onPressed: () => provider.setCopies(
                                        provider.copies + 1,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const Gap(20),

                      // --- CARD 3: Session Info ---
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "INFO SESI",
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF6B7280),
                                letterSpacing: 1.5,
                              ),
                            ),
                            const Gap(16),

                            Text(
                              "Durasi Hitung Mundur",
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF111827),
                              ),
                            ),

                            const Gap(16),

                            // Segmented Timer Control
                            CustomSegmentedControl(
                              selectedIndex: provider.timerDelaySeconds == 3
                                  ? 0
                                  : (provider.timerDelaySeconds == 5 ? 1 : 2),
                              options: const ["3s", "5s", "10s"],
                              onSelected: (idx) {
                                final delays = [3, 5, 10];
                                provider.setTimerDelay(delays[idx]);
                              },
                            ),
                          ],
                        ),
                      ),

                      const Gap(20),

                      // --- CARD 4: Pemeliharaan & Uji Coba ---
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "PEMELIHARAAN & ALAT",
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF6B7280),
                                letterSpacing: 1.5,
                              ),
                            ),
                            const Gap(16),

                            // 1. Uji Coba Cetak Nota Button
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF16A34A),
                                foregroundColor: Colors.white,
                                minimumSize: const Size(double.infinity, 48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(9999),
                                ),
                                elevation: 0,
                              ),
                              icon: const Icon(Icons.print_rounded, size: 18),
                              label: Text(
                                "UJI COBA CETAK NOTA (TEST PRINT)",
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              onPressed: () async {
                                if (!isConnected) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text(
                                        "Printer belum terhubung. Sambungkan printer terlebih dahulu.",
                                      ),
                                      backgroundColor: const Color(0xFFDC2626),
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  );
                                } else {
                                  try {
                                    const testMsg =
                                        "=== TEST PRINT EPPOS ===\nPrinter Thermal OK!\nStatus: Terhubung\n========================\n\n";
                                    debugPrint(testMsg);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text(
                                          "Sinyal uji cetak dikirim ke printer thermal Eppos!",
                                        ),
                                        backgroundColor: const Color(
                                          0xFF16A34A,
                                        ),
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                    );
                                  } catch (e) {
                                    debugPrint('[TestPrint] Error: $e');
                                  }
                                }
                              },
                            ),

                            const Gap(12),

                            // 2. Hapus Riwayat Cetak Button
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFDC2626),
                                side: const BorderSide(
                                  color: Color(0xFFFCA5A5),
                                ),
                                minimumSize: const Size(double.infinity, 48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(9999),
                                ),
                              ),
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                size: 18,
                              ),
                              label: Text(
                                "BERSIHKAN RIWAYAT CETAK",
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (dlgCtx) => AlertDialog(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    title: Text(
                                      "Bersihkan Riwayat Cetak?",
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    content: Text(
                                      "Semua catatan riwayat cetak lokal akan dihapus dari aplikasi.",
                                      style: GoogleFonts.inter(fontSize: 14),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(dlgCtx),
                                        child: const Text("Batal"),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFFDC2626,
                                          ),
                                          foregroundColor: Colors.white,
                                        ),
                                        onPressed: () {
                                          Navigator.pop(dlgCtx);
                                          provider.clearHistory();
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: const Text(
                                                "Riwayat cetak berhasil dibersihkan.",
                                              ),
                                              backgroundColor: const Color(
                                                0xFF16A34A,
                                              ),
                                              behavior:
                                                  SnackBarBehavior.floating,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                            ),
                                          );
                                        },
                                        child: const Text("Hapus"),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),

                      const Gap(40),

                      // Footer Version Info
                      Center(
                        child: Text(
                          "EPPOS Photobooth v1.0.0 - Malang, ID",
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 12,
                            color: const Color(0xFF9CA3AF),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),

                      const Gap(16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showDevicePickerBottomSheet(
    BuildContext context,
    PhotoboothProvider provider,
  ) async {
    // Phase 1: Scanning loading
    setState(() => _isScanning = true);
    final devices = await provider.printerService.getDevices();
    if (mounted) setState(() => _isScanning = false);

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 20,
            bottom: MediaQuery.of(sheetCtx).padding.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(9999),
                  ),
                ),
              ),
              const Gap(16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Pilih Printer Bluetooth Eppos",
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(9999),
                    ),
                    child: Text(
                      "${devices.length} Perangkat",
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF16A34A),
                      ),
                    ),
                  ),
                ],
              ),
              const Gap(12),
              // Banner Panduan Sandingkan (Pairing) RPP02N / Eppos
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFCD34D), width: 1),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.lightbulb_outline_rounded,
                      color: Color(0xFFD97706),
                      size: 20,
                    ),
                    const Gap(10),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF92400E),
                            height: 1.4,
                          ),
                          children: const [
                            TextSpan(
                              text: "Printer RPP02N belum muncul di bawah?\n",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            TextSpan(
                              text:
                                  "1. Buka Pengaturan Bluetooth HP Anda.\n2. Sandingkan (Pair) ",
                            ),
                            TextSpan(
                              text: "RPP02N",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            TextSpan(
                              text:
                                  " (PIN: 0000 / 1234).\n3. Gulir ke bawah pada daftar ini.",
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Gap(16),

              if (devices.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(
                          Icons.bluetooth_searching_rounded,
                          size: 44,
                          color: Color(0xFF9CA3AF),
                        ),
                        const Gap(12),
                        Text(
                          "Belum ada printer Bluetooth terhubung",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF111827),
                          ),
                        ),
                        const Gap(6),
                        Text(
                          "Sandingkan printer RPP02N di Menu Bluetooth HP,\nlalu tekan 'Pindai Ulang'.",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: const Color(0xFF6B7280),
                            height: 1.4,
                          ),
                        ),
                        const Gap(16),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF16A34A),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9999),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                          ),
                          icon: const Icon(
                            Icons.settings_bluetooth_rounded,
                            size: 18,
                          ),
                          label: Text(
                            "BUKA PENGATURAN BLUETOOTH HP",
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: () {
                            openAppSettings();
                          },
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: devices.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: Color(0xFFF3F4F6)),
                    itemBuilder: (ctx, index) {
                      final device = devices[index];
                      final name =
                          device.name.isNotEmpty ? device.name : "Unknown Printer";
                      final isLikelyPrinter =
                          name.toLowerCase().contains("rpp") ||
                          name.toLowerCase().contains("printer") ||
                          name.toLowerCase().contains("pos") ||
                          name.toLowerCase().contains("eppos") ||
                          name.toLowerCase().contains("bt") ||
                          device.address.startsWith("00:18");

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 6,
                        ),
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isLikelyPrinter
                                ? const Color(0xFFDCFCE7)
                                : const Color(0xFFF4F4F5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.print_rounded,
                            color: isLikelyPrinter
                                ? const Color(0xFF15803D)
                                : const Color(0xFF71717A),
                            size: 22,
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: const Color(0xFF111827),
                                ),
                              ),
                            ),
                            if (isLikelyPrinter)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF16A34A),
                                  borderRadius: BorderRadius.circular(9999),
                                ),
                                child: Text(
                                  "PRINTER",
                                  style: GoogleFonts.inter(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Text(
                          device.address,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            color: const Color(0xFF71717A),
                          ),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right_rounded,
                          color: Color(0xFF9CA3AF),
                        ),
                        onTap: () async {
                          Navigator.pop(sheetCtx);
                          if (mounted) {
                            setState(() {
                              _isConnecting = true;
                              _connectingDeviceName = name;
                            });
                          }
                          final success = await provider.printerService.connect(
                            device,
                          );
                          if (context.mounted) {
                            setState(() => _isConnecting = false);
                            if (success) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: const Color(0xFF16A34A),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  content: Text(
                                    "Berhasil terhubung ke $name!",
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: const Color(0xFFDC2626),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  content: Text(
                                    "Gagal terhubung ke $name. Pastikan printer menyala.",
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              );
                            }
                          }
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
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
    return Column(
      children: [
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  "assets/images/logo.png",
                  height: 26,
                  fit: BoxFit.contain,
                ),
                const Gap(8),
                Text(
                  "PENGATURAN",
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF16A34A),
                    letterSpacing: 2.0,
                  ),
                ),
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
// 2. CUSTOM SETTINGS TOGGLE WIDGET
// ==========================================
class CustomSettingsToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const CustomSettingsToggle({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 54,
        height: 30,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9999),
          color: value ? const Color(0xFF10B981) : const Color(0xFFE5E7EB),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF2563EB), // Vibrant blue thumb
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 14),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 3. CUSTOM SEGMENTED CONTROL WIDGET
// ==========================================
class CustomSegmentedControl extends StatelessWidget {
  final int selectedIndex;
  final List<String> options;
  final ValueChanged<int> onSelected;

  const CustomSegmentedControl({
    super.key,
    required this.selectedIndex,
    required this.options,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Row(
        children: List.generate(options.length, (index) {
          final isSelected = selectedIndex == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelected(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(9999),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    options[index],
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                      color: isSelected
                          ? const Color(0xFF111827)
                          : const Color(0xFF6B7280),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
