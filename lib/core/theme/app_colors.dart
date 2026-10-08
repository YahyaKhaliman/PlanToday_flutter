import 'package:flutter/material.dart';

/// Design tokens sesuai DESIGN.md PlanToday Mobile
class AppColors {
  // Brand
  static const Color primary = Color(0xFF4F46E5); // Indigo (#4F46E5)
  static const Color accent = Color(0xFF06B6D4); // Cyan (#06B6D4)

  // Feedback
  static const Color success = Color(0xFF16A34A);
  static const Color danger = Color(0xFFEF4444);
  static const Color info = Color(0xFF0369A1);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningBg = Color(0xFFFEF3C7);
  static const Color warningBorder = Color(0xFFFCD34D);
  static const Color warningText = Color(0xFF92400E);
  static const Color wa = Color(0xFF22C55E); // Hijau WhatsApp

  // Neutral
  static const Color ink = Color(0xFF0F172A); // Slate gelap (Teks utama)
  static const Color muted = Color(0xFF64748B); // Slate abu-abu (Teks sekunder)
  static const Color card = Color(0xFFFFFFFF);
  static const Color soft = Color(0xFFF1F5F9); // Latar lembut
  static const Color border = Color(0x140F172A); // rgba(15,23,42,0.08)
  static const Color overlay = Color(0x730F172A); // rgba(15,23,42,0.45)
  static const Color bgTop = Color(0xFFF7F9FF);
  static const Color bgBottom = Color(0xFFFFFFFF);
}

/// Token Status Transaksi Penawaran
class StatusColors {
  static const Color wait = Color(0xFFD97706); // Menunggu
  static const Color acc = Color(0xFF16A34A); // Diterima / Selesai
  static const Color tolak = Color(0xFFDC2626); // Ditolak
}

/// Token Status Perusahaan / Divisi
class CompanyStatusToken {
  final Color base;
  final Color text;

  const CompanyStatusToken({required this.base, required this.text});
}

class CompanyStatusColors {
  static const belum = CompanyStatusToken(base: Color(0xFF6B7280), text: Color(0xFF374151));
  static const minta = CompanyStatusToken(base: Color(0xFFDC2626), text: Color(0xFF991B1B));
  static const wait = CompanyStatusToken(base: Color(0xFF16A34A), text: Color(0xFF15803D));
  static const nego = CompanyStatusToken(base: Color(0xFF6B21A8), text: Color(0xFF4A044E));
  static const done = CompanyStatusToken(base: Color(0xFF18181B), text: Color(0xFF09090B));
  static const cancel = CompanyStatusToken(base: Color(0xFF2563EB), text: Color(0xFF1D4ED8));
  static const def = CompanyStatusToken(base: Color(0xFF6366F1), text: Color(0xFF4F46E5));
}

class AppRadius {
  static const double small = 8.0;
  static const double medium = 12.0;
  static const double large = 16.0;
  static const double card = 24.0;
}

class AppShadows {
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x0F000000), // rgba(0,0,0,0.06)
      blurRadius: 18,
      offset: Offset(0, 10),
    ),
  ];

  static const List<BoxShadow> softCard = [
    BoxShadow(
      color: Color(0x0D000000), // rgba(0,0,0,0.05)
      blurRadius: 14,
      offset: Offset(0, 8),
    ),
  ];
}
