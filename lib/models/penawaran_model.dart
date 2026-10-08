class PenawaranListItem {
  final String nomor;
  final String tanggal;
  final String divisi;
  final String tipe;
  final String perusahaan;
  final String customer;
  final String sales;
  final String keterangan;
  final double nominal;
  final int detailCount;
  final String approvalState; // '' | 'WAIT' | 'ACC' | 'TOLAK'
  final bool isApproved;

  const PenawaranListItem({
    required this.nomor,
    required this.tanggal,
    this.divisi = '',
    this.tipe = '',
    this.perusahaan = '',
    this.customer = '',
    this.sales = '',
    this.keterangan = '',
    this.nominal = 0.0,
    this.detailCount = 0,
    this.approvalState = '',
    this.isApproved = false,
  });

  factory PenawaranListItem.fromJson(Map<String, dynamic> json) {
    return PenawaranListItem(
      nomor: json['nomor']?.toString() ?? '',
      tanggal: json['tanggal']?.toString() ?? '',
      divisi: json['divisi']?.toString() ?? '',
      tipe: json['tipe']?.toString() ?? '',
      perusahaan: json['perusahaan']?.toString() ?? '',
      customer: json['customer']?.toString() ?? '',
      sales: json['sales']?.toString() ?? '',
      keterangan: json['keterangan']?.toString() ?? '',
      nominal: (json['nominal'] as num?)?.toDouble() ?? 0.0,
      detailCount: (json['detail_count'] as num?)?.toInt() ?? 0,
      approvalState: json['approval_state']?.toString() ?? '',
      isApproved: json['is_approved'] == 1 || json['is_approved'] == true,
    );
  }
}

class PenawaranDetailItem {
  final String id;
  final int urutan;
  final String namaBarang;
  final String bahan;
  final String ukuran;
  final double panjang;
  final double lebar;
  final String satuan;
  final double qty;
  final double harga;
  final double total;
  final String status;

  const PenawaranDetailItem({
    required this.id,
    this.urutan = 0,
    required this.namaBarang,
    this.bahan = '',
    this.ukuran = '',
    this.panjang = 0.0,
    this.lebar = 0.0,
    this.satuan = 'pcs',
    this.qty = 0.0,
    this.harga = 0.0,
    this.total = 0.0,
    this.status = '',
  });

  factory PenawaranDetailItem.fromJson(Map<String, dynamic> json) {
    return PenawaranDetailItem(
      id: json['id']?.toString() ?? '',
      urutan: (json['urutan'] as num?)?.toInt() ?? 0,
      namaBarang: json['nama_barang']?.toString() ?? '',
      bahan: json['bahan']?.toString() ?? '',
      ukuran: json['ukuran']?.toString() ?? '',
      panjang: (json['panjang'] as num?)?.toDouble() ?? 0.0,
      lebar: (json['lebar'] as num?)?.toDouble() ?? 0.0,
      satuan: json['satuan']?.toString() ?? 'pcs',
      qty: (json['qty'] as num?)?.toDouble() ?? 0.0,
      harga: (json['harga'] as num?)?.toDouble() ?? 0.0,
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      status: json['status']?.toString() ?? '',
    );
  }
}
