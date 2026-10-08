class PermintaanHargaItem {
  final String nomor;
  final String tanggal;
  final String nama;
  final String customer;
  final String divisi;
  final double jmlOrder;
  final double harga;
  final double hargaKalkulasi;
  final String status;
  final String ketKalkulasi;
  final String userCreate;

  const PermintaanHargaItem({
    required this.nomor,
    required this.tanggal,
    this.nama = '',
    this.customer = '',
    this.divisi = '',
    this.jmlOrder = 0.0,
    this.harga = 0.0,
    this.hargaKalkulasi = 0.0,
    this.status = '',
    this.ketKalkulasi = '',
    this.userCreate = '',
  });

  factory PermintaanHargaItem.fromJson(Map<String, dynamic> json) {
    return PermintaanHargaItem(
      nomor: json['nomor']?.toString() ?? '',
      tanggal: json['tanggal']?.toString() ?? json['created_at_fmt']?.toString() ?? '',
      nama: json['nama']?.toString() ?? '',
      customer: json['customer']?.toString() ?? '',
      divisi: json['divisi']?.toString() ?? '',
      jmlOrder: (json['jml_order'] as num?)?.toDouble() ?? 0.0,
      harga: (json['harga'] as num?)?.toDouble() ?? (json['mh_harga'] as num?)?.toDouble() ?? 0.0,
      hargaKalkulasi: (json['harga_kalkulasi'] as num?)?.toDouble() ?? 0.0,
      status: json['status']?.toString() ?? '',
      ketKalkulasi: json['ket_kalkulasi']?.toString() ?? '',
      userCreate: json['user_create']?.toString() ?? '',
    );
  }
}

class PermintaanHargaDetail {
  final String nomor;
  final String tanggal;
  final String divisi;
  final String cusKode;
  final String cusNama;
  final String nama;
  final double jmlOrder;
  final double harga;
  final double budget;
  final String kain;
  final String gambarUrl;
  final String keterangan;

  const PermintaanHargaDetail({
    required this.nomor,
    required this.tanggal,
    this.divisi = '',
    this.cusKode = '',
    this.cusNama = '',
    this.nama = '',
    this.jmlOrder = 0.0,
    this.harga = 0.0,
    this.budget = 0.0,
    this.kain = '',
    this.gambarUrl = '',
    this.keterangan = '',
  });

  factory PermintaanHargaDetail.fromJson(Map<String, dynamic> json) {
    return PermintaanHargaDetail(
      nomor: json['mh_nomor']?.toString() ?? json['nomor']?.toString() ?? '',
      tanggal: json['mh_tanggal']?.toString() ?? json['tanggal']?.toString() ?? '',
      divisi: json['mh_divisi']?.toString() ?? '',
      cusKode: json['mh_cus_kode']?.toString() ?? '',
      cusNama: json['mh_cus_nama']?.toString() ?? '',
      nama: json['mh_nama']?.toString() ?? '',
      jmlOrder: (json['mh_jmlorder'] as num?)?.toDouble() ?? 0.0,
      harga: (json['mh_harga'] as num?)?.toDouble() ?? 0.0,
      budget: (json['mh_budget'] as num?)?.toDouble() ?? 0.0,
      kain: json['mh_kain']?.toString() ?? '',
      gambarUrl: json['mh_gambar']?.toString() ?? '',
      keterangan: json['mh_ket']?.toString() ?? '',
    );
  }
}
