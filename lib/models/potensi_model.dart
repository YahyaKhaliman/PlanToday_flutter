class PotensiListItem {
  final String nomor;
  final String salesNama;
  final String customerNama;
  final String namaItem;
  final double harga;
  final String status;
  final String? tanggal;
  final String? alasanBatal;

  const PotensiListItem({
    required this.nomor,
    this.salesNama = '',
    this.customerNama = '',
    this.namaItem = '',
    this.harga = 0.0,
    this.status = 'OPEN',
    this.tanggal,
    this.alasanBatal,
  });

  factory PotensiListItem.fromJson(Map<String, dynamic> json) {
    return PotensiListItem(
      nomor: json['pot_nomor']?.toString() ?? json['nomor']?.toString() ?? '',
      salesNama: json['sales_nama']?.toString() ?? json['sal_nama']?.toString() ?? '',
      customerNama: json['customer_nama']?.toString() ?? json['cus_nama']?.toString() ?? '',
      namaItem: json['nama_item']?.toString() ?? json['pot_nama_item']?.toString() ?? '',
      harga: (json['harga'] as num?)?.toDouble() ?? (json['pot_harga'] as num?)?.toDouble() ?? 0.0,
      status: json['status']?.toString() ?? json['pot_status']?.toString() ?? 'OPEN',
      tanggal: json['pot_tanggal']?.toString() ?? json['tanggal']?.toString(),
      alasanBatal: json['alasan_batal']?.toString() ?? json['pot_alasan_batal']?.toString(),
    );
  }
}

class PotensiKpiSummary {
  final int totalCount;
  final int openCount;
  final int closeCount;
  final int batalCount;
  final double totalNominal;
  final double openNominal;
  final double closeNominal;
  final double batalNominal;
  final double closingRatePct;

  const PotensiKpiSummary({
    this.totalCount = 0,
    this.openCount = 0,
    this.closeCount = 0,
    this.batalCount = 0,
    this.totalNominal = 0.0,
    this.openNominal = 0.0,
    this.closeNominal = 0.0,
    this.batalNominal = 0.0,
    this.closingRatePct = 0.0,
  });

  factory PotensiKpiSummary.fromJson(Map<String, dynamic> json) {
    return PotensiKpiSummary(
      totalCount: (json['total_count'] as num?)?.toInt() ?? 0,
      openCount: (json['open_count'] as num?)?.toInt() ?? 0,
      closeCount: (json['close_count'] as num?)?.toInt() ?? 0,
      batalCount: (json['batal_count'] as num?)?.toInt() ?? 0,
      totalNominal: (json['total_nominal'] as num?)?.toDouble() ?? 0.0,
      openNominal: (json['open_nominal'] as num?)?.toDouble() ?? 0.0,
      closeNominal: (json['close_nominal'] as num?)?.toDouble() ?? 0.0,
      batalNominal: (json['batal_nominal'] as num?)?.toDouble() ?? 0.0,
      closingRatePct: (json['closing_rate_pct'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
