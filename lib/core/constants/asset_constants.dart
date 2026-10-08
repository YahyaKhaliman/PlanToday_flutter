class AppAssets {
  static const String basePath = 'assets/images';

  // Logo Aplikasi
  static const String logo = '$basePath/logo.png';

  // Kop Surat Perusahaan (Header Dokumen)
  static const String kopJaya = '$basePath/jaya.jpg';
  static const String kopKp = '$basePath/kp.jpg';
  static const String kopMadani = '$basePath/madani.jpg';

  // Kop Khusus Penawaran
  static const String penawaranJaya = '$basePath/pen_ja.jpg';
  static const String penawaranKp = '$basePath/pen_kp.jpg';
  static const String penawaranMadani = '$basePath/pen_md.jpg';

  /// Mendapatkan path gambar kop penawaran berdasarkan kode perusahaan
  static String getPenawaranKop(String perusahaanKode) {
    final code = perusahaanKode.toUpperCase().trim();
    if (code.contains('JAY') || code.contains('JA')) {
      return penawaranJaya;
    } else if (code.contains('MAD') || code.contains('MD')) {
      return penawaranMadani;
    }
    // Default Kencana Print
    return penawaranKp;
  }

  /// Mendapatkan path gambar kop surat umum berdasarkan kode perusahaan
  static String getKopSurat(String perusahaanKode) {
    final code = perusahaanKode.toUpperCase().trim();
    if (code.contains('JAY') || code.contains('JA')) {
      return kopJaya;
    } else if (code.contains('MAD') || code.contains('MD')) {
      return kopMadani;
    }
    // Default Kencana Print
    return kopKp;
  }
}
