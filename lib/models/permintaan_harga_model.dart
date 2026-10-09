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
      nomor: json['nomor']?.toString() ?? json['mh_nomor']?.toString() ?? '',
      tanggal: json['tanggal']?.toString() ?? json['created_at_fmt']?.toString() ?? json['mh_tanggal']?.toString() ?? '',
      nama: json['nama']?.toString() ?? json['mh_nama']?.toString() ?? '',
      customer: json['customer']?.toString() ?? json['mh_cus_nama']?.toString() ?? '',
      divisi: json['divisi']?.toString() ?? json['mh_divisi']?.toString() ?? '',
      jmlOrder: (json['jml_order'] as num?)?.toDouble() ?? (json['mh_jmlorder'] as num?)?.toDouble() ?? 0.0,
      harga: (json['harga'] as num?)?.toDouble() ?? (json['mh_harga'] as num?)?.toDouble() ?? 0.0,
      hargaKalkulasi: (json['harga_kalkulasi'] as num?)?.toDouble() ?? (json['mh_harga_kalkulasi'] as num?)?.toDouble() ?? 0.0,
      status: json['status']?.toString() ?? json['mh_status']?.toString() ?? '',
      ketKalkulasi: json['ket_kalkulasi']?.toString() ?? json['mh_ket_kalkulasi']?.toString() ?? '',
      userCreate: json['user_create']?.toString() ?? '',
    );
  }
}

class PermintaanHargaDetail {
  final String nomor;
  final String tanggal;
  final String divisi;
  final String divisiNama;
  final String cusKode;
  final String cusNama;
  final String nama;
  final double jmlOrder;
  final double harga;
  final double budget;
  final double hargaKalkulasi;
  final double ongkir;
  final String kain;
  final double panjang;
  final double lebar;
  final String ukuran;
  final String gramasi;
  final String finishing;
  final String sublim;
  final String warna;
  final String gambarUrl;
  final String keterangan;
  final String userCreate;
  final String salesNama;

  const PermintaanHargaDetail({
    required this.nomor,
    required this.tanggal,
    this.divisi = '',
    this.divisiNama = '',
    this.cusKode = '',
    this.cusNama = '',
    this.nama = '',
    this.jmlOrder = 0.0,
    this.harga = 0.0,
    this.budget = 0.0,
    this.hargaKalkulasi = 0.0,
    this.ongkir = 0.0,
    this.kain = '',
    this.panjang = 0.0,
    this.lebar = 0.0,
    this.ukuran = '',
    this.gramasi = '',
    this.finishing = '',
    this.sublim = '',
    this.warna = '',
    this.gambarUrl = '',
    this.keterangan = '',
    this.userCreate = '',
    this.salesNama = '',
  });

  factory PermintaanHargaDetail.fromJson(Map<String, dynamic> json) {
    return PermintaanHargaDetail(
      nomor: json['mh_nomor']?.toString() ?? json['nomor']?.toString() ?? '',
      tanggal: json['mh_tanggal']?.toString() ?? json['tanggal']?.toString() ?? '',
      divisi: json['mh_divisi']?.toString() ?? json['divisi']?.toString() ?? '',
      divisiNama: json['divisi_nama']?.toString() ?? '',
      cusKode: json['mh_cus_kode']?.toString() ?? '',
      cusNama: json['mh_cus_nama']?.toString() ?? json['customer']?.toString() ?? '',
      nama: json['mh_nama']?.toString() ?? json['nama']?.toString() ?? '',
      jmlOrder: (json['mh_jmlorder'] as num?)?.toDouble() ?? (json['jml_order'] as num?)?.toDouble() ?? 0.0,
      harga: (json['mh_harga'] as num?)?.toDouble() ?? (json['harga'] as num?)?.toDouble() ?? 0.0,
      budget: (json['mh_budget'] as num?)?.toDouble() ?? 0.0,
      hargaKalkulasi: (json['mh_harga_kalkulasi'] as num?)?.toDouble() ?? (json['harga_kalkulasi'] as num?)?.toDouble() ?? 0.0,
      ongkir: (json['mh_ongkir'] as num?)?.toDouble() ?? (json['kald_rpkirim'] as num?)?.toDouble() ?? 0.0,
      kain: json['mh_kain']?.toString() ?? '',
      panjang: (json['mh_panjang'] as num?)?.toDouble() ?? 0.0,
      lebar: (json['mh_lebar'] as num?)?.toDouble() ?? 0.0,
      ukuran: json['mh_ukuran']?.toString() ?? '',
      gramasi: json['mh_gramasi']?.toString() ?? '',
      finishing: json['mh_finishing']?.toString() ?? '',
      sublim: json['mh_sublim']?.toString() ?? '',
      warna: json['mh_warna']?.toString() ?? '',
      gambarUrl: json['mh_gambar']?.toString() ?? '',
      keterangan: json['mh_ket']?.toString() ?? '',
      userCreate: json['user_create']?.toString() ?? '',
      salesNama: json['sales_nama']?.toString() ?? '',
    );
  }
}
