class VisitModel {
  final int? id;
  final String? cusKode;
  final String cusNama;
  final String cusAlamat;
  final String tanggal;
  final String note;
  final String catatan;
  final String? realisasi;
  final double? latitude;
  final double? longitude;
  final String? fotoUrl;

  const VisitModel({
    this.id,
    this.cusKode,
    required this.cusNama,
    this.cusAlamat = '',
    required this.tanggal,
    this.note = '',
    this.catatan = '',
    this.realisasi,
    this.latitude,
    this.longitude,
    this.fotoUrl,
  });

  factory VisitModel.fromJson(Map<String, dynamic> json) {
    return VisitModel(
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id']?.toString() ?? ''),
      cusKode: json['cus_kode']?.toString(),
      cusNama: json['cus_nama']?.toString() ?? json['cc_nama']?.toString() ?? json['customer_text']?.toString() ?? '',
      cusAlamat: json['cus_alamat']?.toString() ?? json['cc_alamat']?.toString() ?? json['cus_alamat_text']?.toString() ?? '',
      tanggal: json['tanggal']?.toString() ?? json['tanggal_plan']?.toString() ?? '',
      note: json['note']?.toString() ?? '',
      catatan: json['catatan']?.toString() ?? '',
      realisasi: json['realisasi']?.toString(),
      latitude: (json['latitude'] as num?)?.toDouble() ?? double.tryParse(json['latitude']?.toString() ?? ''),
      longitude: (json['longitude'] as num?)?.toDouble() ?? double.tryParse(json['longitude']?.toString() ?? ''),
      fotoUrl: json['foto_url']?.toString() ?? json['foto']?.toString(),
    );
  }
}
