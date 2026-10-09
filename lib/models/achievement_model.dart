class AchievementUserRow {
  final String kode;
  final String nama;
  final String jabatan;
  final double target;
  final double realisasi;
  final double ach; // persentase achievement

  const AchievementUserRow({
    required this.kode,
    required this.nama,
    this.jabatan = '',
    this.target = 0.0,
    this.realisasi = 0.0,
    this.ach = 0.0,
  });

  factory AchievementUserRow.fromJson(Map<String, dynamic> json) {
    return AchievementUserRow(
      kode: json['kode']?.toString() ?? '',
      nama: json['nama']?.toString() ?? '-',
      jabatan: json['jabatan']?.toString() ?? '-',
      target: (json['target'] as num?)?.toDouble() ?? 0.0,
      realisasi: (json['realisasi'] as num?)?.toDouble() ?? 0.0,
      ach: (json['ach'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class AchievementMonthlyItem {
  final String bulan;
  final int bulanNum;
  final int tahun;
  final double target;
  final double realisasi;
  final double ach;

  const AchievementMonthlyItem({
    required this.bulan,
    this.bulanNum = 0,
    this.tahun = 0,
    this.target = 0.0,
    this.realisasi = 0.0,
    this.ach = 0.0,
  });

  factory AchievementMonthlyItem.fromJson(Map<String, dynamic> json) {
    return AchievementMonthlyItem(
      bulan: json['bulan']?.toString() ?? json['month_label']?.toString() ?? '',
      bulanNum: (json['bulan_num'] as num?)?.toInt() ?? (json['month'] as num?)?.toInt() ?? 0,
      tahun: (json['tahun'] as num?)?.toInt() ?? (json['year'] as num?)?.toInt() ?? 0,
      target: (json['target'] as num?)?.toDouble() ?? 0.0,
      realisasi: (json['realisasi'] as num?)?.toDouble() ?? 0.0,
      ach: (json['ach'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
