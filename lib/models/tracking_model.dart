class TrackingPenawaranListItem {
  final String noPenawaran;
  final String tanggalPenawaran;
  final String customer;
  final String sales;
  final int totalItem;
  final int totalItemMap;
  final String noMap;
  final String mapStatus;
  final String mapDeadline;
  final String mapWorkshop;
  final String mapKeterangan;
  final String mapKendala;
  final String statusTracking; // 'OPEN' | 'PARSIAL' | 'CLOSE'

  const TrackingPenawaranListItem({
    required this.noPenawaran,
    required this.tanggalPenawaran,
    this.customer = '',
    this.sales = '',
    this.totalItem = 0,
    this.totalItemMap = 0,
    this.noMap = '',
    this.mapStatus = '',
    this.mapDeadline = '',
    this.mapWorkshop = '',
    this.mapKeterangan = '',
    this.mapKendala = '',
    this.statusTracking = 'OPEN',
  });

  factory TrackingPenawaranListItem.fromJson(Map<String, dynamic> json) {
    return TrackingPenawaranListItem(
      noPenawaran: json['no_penawaran']?.toString() ?? '',
      tanggalPenawaran: json['tanggal_penawaran']?.toString() ?? '',
      customer: json['customer']?.toString() ?? '',
      sales: json['sales']?.toString() ?? '',
      totalItem: (json['total_item'] as num?)?.toInt() ?? 0,
      totalItemMap: (json['total_item_map'] as num?)?.toInt() ?? 0,
      noMap: json['no_map']?.toString() ?? '',
      mapStatus: json['map_status']?.toString() ?? '',
      mapDeadline: json['map_deadline']?.toString() ?? '',
      mapWorkshop: json['map_workshop']?.toString() ?? '',
      mapKeterangan: json['map_keterangan']?.toString() ?? '',
      mapKendala: json['map_kendala']?.toString() ?? '',
      statusTracking: json['status_tracking']?.toString() ?? 'OPEN',
    );
  }
}

class TrackingMapListItem {
  final String noMap;
  final String customer;
  final String alamat;
  final String tanggalMap;
  final String tanggalBast;
  final String nomorSj;
  final String mspkNama;
  final String mspkUkuran;
  final String mspkKain;
  final String sales;

  const TrackingMapListItem({
    required this.noMap,
    this.customer = '',
    this.alamat = '',
    this.tanggalMap = '',
    this.tanggalBast = '',
    this.nomorSj = '',
    this.mspkNama = '',
    this.mspkUkuran = '',
    this.mspkKain = '',
    this.sales = '',
  });

  factory TrackingMapListItem.fromJson(Map<String, dynamic> json) {
    return TrackingMapListItem(
      noMap: json['no_map']?.toString() ?? '',
      customer: json['customer']?.toString() ?? '',
      alamat: json['alamat']?.toString() ?? '',
      tanggalMap: json['tanggal_map']?.toString() ?? '',
      tanggalBast: json['tanggal_bast']?.toString() ?? '',
      nomorSj: json['nomor_sj']?.toString() ?? '',
      mspkNama: json['mspk_nama']?.toString() ?? '',
      mspkUkuran: json['mspk_ukuran']?.toString() ?? '',
      mspkKain: json['mspk_kain']?.toString() ?? '',
      sales: json['sales']?.toString() ?? '',
    );
  }
}

class TrackingSpkListItem {
  final String noSpk;
  final String tanggalSpk;
  final String customer;
  final String sales;
  final String namaBarang;
  final double qty;
  final double realisasiTotal;
  final String status;

  const TrackingSpkListItem({
    required this.noSpk,
    this.tanggalSpk = '',
    this.customer = '',
    this.sales = '',
    this.namaBarang = '',
    this.qty = 0.0,
    this.realisasiTotal = 0.0,
    this.status = '',
  });

  factory TrackingSpkListItem.fromJson(Map<String, dynamic> json) {
    final qty = (json['spk_jumlah'] as num?)?.toDouble() ??
        (json['qty'] as num?)?.toDouble() ??
        0.0;
    final realisasi = (json['realisasi_total'] as num?)?.toDouble() ?? 0.0;
    String computedStatus = json['status']?.toString() ?? '';
    if (computedStatus.isEmpty) {
      if (qty > 0 && realisasi >= qty - 0.01) {
        computedStatus = 'CLOSE';
      } else if (realisasi > 0) {
        computedStatus = 'PROSES';
      } else {
        computedStatus = 'OPEN';
      }
    }

    return TrackingSpkListItem(
      noSpk: json['spk_nomor']?.toString() ??
          json['no_spk']?.toString() ??
          json['mspk_nomor']?.toString() ??
          '',
      tanggalSpk: json['spk_tanggal']?.toString() ??
          json['tanggal_spk']?.toString() ??
          '',
      customer: json['customer']?.toString() ?? '',
      sales: json['sales']?.toString() ?? '',
      namaBarang: json['spk_nama']?.toString() ??
          json['nama_barang']?.toString() ??
          json['mspk_nama']?.toString() ??
          '',
      qty: qty,
      realisasiTotal: realisasi,
      status: computedStatus,
    );
  }
}
