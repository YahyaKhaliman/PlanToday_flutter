import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive_helper.dart';
import '../../engines/kalkulasi_engine.dart';
import '../../engines/ongkir_engine.dart';
import '../../models/kalkulasi_models.dart';
import '../../widgets/ui/app_button.dart';
import '../../widgets/ui/app_card.dart';

class PermintaanHargaFormScreen extends ConsumerStatefulWidget {
  const PermintaanHargaFormScreen({super.key});

  @override
  ConsumerState<PermintaanHargaFormScreen> createState() =>
      _PermintaanHargaFormScreenState();
}

class _PermintaanHargaFormScreenState
    extends ConsumerState<PermintaanHargaFormScreen> {
  final _customerNamaController = TextEditingController();
  final _barangController = TextEditingController();
  final _qtyController = TextEditingController(text: '100');
  final _budgetController = TextEditingController();
  final _alokasiKotaController = TextEditingController(text: 'Jakarta');

  // Parameter Operasional Biaya (sesuai kalkulasiEngine)
  final _biayaPotongController = TextEditingController(text: '1000');
  final _biayaJahitController = TextEditingController(text: '3000');
  final _biayaFinishingController = TextEditingController(text: '500');

  // Dimensi Custom (Bordir & DTF)
  double _bordirPanjang = 5.0;
  double _bordirLebar = 5.0;
  final double _bordirCmRate = 50.0;

  // Persentase
  final double _allowancePct = 5.0;
  double _labaPct = 10.0;
  final double _ppnPct = 11.0;

  // Hasil Kalkulasi Realtime
  KalkulasiCalculationResult? _kalkulasiResult;
  OngkirCalcResult? _ongkirResult;

  @override
  void initState() {
    super.initState();
    _recalculate();
  }

  @override
  void dispose() {
    _customerNamaController.dispose();
    _barangController.dispose();
    _qtyController.dispose();
    _budgetController.dispose();
    _alokasiKotaController.dispose();
    _biayaPotongController.dispose();
    _biayaJahitController.dispose();
    _biayaFinishingController.dispose();
    super.dispose();
  }

  void _recalculate() {
    final qty = double.tryParse(_qtyController.text) ?? 100.0;
    final rpPotong = double.tryParse(_biayaPotongController.text) ?? 0.0;
    final rpJahit = double.tryParse(_biayaJahitController.text) ?? 0.0;
    final rpFinishing = double.tryParse(_biayaFinishingController.text) ?? 0.0;

    // 1. Jalankan Kalkulasi HPP & Harga
    final state = KalkulasiState(
      rencanaOrder: qty,
      rpPotong: rpPotong,
      rpJahit: rpJahit,
      rpFinishing: rpFinishing,
      gridKomponen: [
        const KomponenKainItem(
          komponen: 'Badan & Lengan',
          kg: true,
          harga: 80000,
          babaran: 3.0,
        ),
      ],
      bordir: Dimension8Slots(
        cm: _bordirCmRate,
        p1: _bordirPanjang,
        l1: _bordirLebar,
      ),
      persenAllowance: _allowancePct,
      persenLaba: _labaPct,
      persenPpn: _ppnPct,
    );

    final kResult = KalkulasiEngine.calculatePrice(state, qty);

    // 2. Jalankan Kalkulasi Ongkir Otomatis
    final oResult = OngkirEngine.hitungOngkirOtomatis(
      alokasi: _alokasiKotaController.text.trim(),
      divisi: '4', // Garmen / Kaos
      qty: qty,
    );

    setState(() {
      _kalkulasiResult = kResult;
      _ongkirResult = oResult;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat =
        NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FF),
      body: SafeArea(
        child: ResponsiveContainer(
          maxWidth: 600,
          child: Column(
            children: [
              // 1. TOP HEADER ALA UI-STYLING
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => context.pop(),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color.fromRGBO(15, 23, 42, 0.08),
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color.fromRGBO(15, 23, 42, 0.03),
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.chevron_left_rounded,
                          size: 26,
                          color: Color(0xFF4F46E5),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: const [
                          Text(
                            'Kalkulator Harga',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Simulasi harga & estimasi ongkir otomatis',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 42),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 2. FORM KONTEN
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Identitas Pesanan
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Data Pesanan',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _customerNamaController,
                              decoration: const InputDecoration(
                                labelText: 'Nama Customer',
                                prefixIcon: Icon(Icons.person_outline, size: 20),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _barangController,
                              decoration: const InputDecoration(
                                labelText: 'Nama Barang / Model',
                                prefixIcon: Icon(Icons.checkroom_outlined, size: 20),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _qtyController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'Order Qty (pcs)',
                                      prefixIcon: Icon(Icons.numbers_outlined, size: 20),
                                    ),
                                    onChanged: (_) => _recalculate(),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: _alokasiKotaController,
                                    decoration: const InputDecoration(
                                      labelText: 'Tujuan Kirim / Kota',
                                      prefixIcon: Icon(Icons.location_city_outlined, size: 20),
                                    ),
                                    onChanged: (_) => _recalculate(),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Parameter Bordir & Desain
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Spesifikasi Bordir',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Panjang: ${_bordirPanjang.toStringAsFixed(1)} cm',
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                ),
                                Text(
                                  'Lebar: ${_bordirLebar.toStringAsFixed(1)} cm',
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                ),
                              ],
                            ),
                            Slider(
                              value: _bordirPanjang,
                              min: 0,
                              max: 30,
                              activeColor: const Color(0xFF4F46E5),
                              onChanged: (v) {
                                setState(() => _bordirPanjang = v);
                                _recalculate();
                              },
                            ),
                            Slider(
                              value: _bordirLebar,
                              min: 0,
                              max: 30,
                              activeColor: const Color(0xFF00B4D8),
                              onChanged: (v) {
                                setState(() => _bordirLebar = v);
                                _recalculate();
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Margin & Allowance
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Margin & Allowance',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Allowance: ${_allowancePct.toInt()}%',
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                                Text(
                                  'Laba: ${_labaPct.toInt()}%',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                    color: Color(0xFF4F46E5),
                                  ),
                                ),
                              ],
                            ),
                            Slider(
                              value: _labaPct,
                              min: 0,
                              max: 50,
                              divisions: 10,
                              activeColor: const Color(0xFF4F46E5),
                              onChanged: (v) {
                                setState(() => _labaPct = v);
                                _recalculate();
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Hasil Perhitungan Engine Card
                      if (_kalkulasiResult != null)
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF4F46E5), Color(0xFF00B4D8)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: AppShadows.card,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'HASIL KALKULASI HARGA (PER PCS)',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 14),
                              _ResultLine(
                                label: 'Total HPP Murni:',
                                value: currencyFormat
                                    .format(_kalkulasiResult!.hppMurni.round()),
                              ),
                              _ResultLine(
                                label: 'Harga Sesuai (Excl. PPN):',
                                value: currencyFormat
                                    .format(_kalkulasiResult!.hargaSesuai),
                              ),
                              _ResultLine(
                                label: 'Harga Rekomendasi (Inc. PPN):',
                                value: currencyFormat
                                    .format(_kalkulasiResult!.hargaSesuaiPpn),
                                isHighlight: true,
                              ),
                              if (_ongkirResult != null) ...[
                                const Divider(color: Colors.white24, height: 20),
                                Text(
                                  'Ongkir: ${_ongkirResult!.ringkasan}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Ongkir / Pcs: ${currencyFormat.format(_ongkirResult!.ongkirPerPcs)}',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      const SizedBox(height: 20),

                      AppButton(
                        text: 'Gunakan Harga Ini',
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Harga kalkulasi disimpan ke sistem'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                          context.pop();
                        },
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultLine extends StatelessWidget {
  final String label;
  final String value;
  final bool isHighlight;

  const _ResultLine({
    required this.label,
    required this.value,
    this.isHighlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isHighlight ? Colors.white : Colors.white70,
              fontSize: isHighlight ? 14 : 12,
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: isHighlight ? 16 : 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
