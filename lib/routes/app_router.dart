import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../screens/achievement/achievement_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/customer/rekap_calon_customer_screen.dart';
import '../screens/customer/tambah_calon_customer_screen.dart';
import '../screens/home/ganti_password_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/kurir/kurir_menu_screen.dart';
import '../screens/penawaran/penawaran_detail_screen.dart';
import '../screens/penawaran/penawaran_list_screen.dart';
import '../screens/penawaran/tracking_map_screen.dart';
import '../screens/penawaran/tracking_penawaran_screen.dart';
import '../screens/penawaran/tracking_spk_screen.dart';
import '../screens/permintaan_harga/permintaan_harga_detail_screen.dart';
import '../screens/permintaan_harga/permintaan_harga_form_screen.dart';
import '../screens/permintaan_harga/permintaan_harga_list_screen.dart';
import '../screens/potensi/potensi_screen.dart';
import '../screens/visit/tambah_visit_screen.dart';
import '../screens/visit/visit_plan_screen.dart';
import '../screens/visit/visit_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      if (authState.isLoading) return null;

      final isLoggingIn = state.matchedLocation == '/login';
      final isRegistering = state.matchedLocation == '/register';

      if (!authState.isAuthenticated) {
        return (isLoggingIn || isRegistering) ? null : '/login';
      }

      if (isLoggingIn || isRegistering) {
        return '/';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),

      // Modul Customer
      GoRoute(
        path: '/customer',
        name: 'customer',
        builder: (context, state) => const RekapCalonCustomerScreen(),
        routes: [
          GoRoute(
            path: 'tambah',
            name: 'tambah-customer',
            builder: (context, state) => const TambahCalonCustomerScreen(),
          ),
        ],
      ),

      // Modul Visit
      GoRoute(
        path: '/visit',
        name: 'visit',
        builder: (context, state) => const VisitScreen(),
        routes: [
          GoRoute(
            path: 'tambah',
            name: 'tambah-visit',
            builder: (context, state) => const TambahVisitScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/visit-plan',
        name: 'visit-plan',
        builder: (context, state) => const VisitPlanScreen(),
      ),

      // Modul Penawaran
      GoRoute(
        path: '/penawaran',
        name: 'penawaran',
        builder: (context, state) => const PenawaranListScreen(),
        routes: [
          GoRoute(
            path: ':nomor',
            name: 'penawaran-detail',
            builder: (context, state) {
              final nomor = state.pathParameters['nomor'] ?? '';
              return PenawaranDetailScreen(nomor: nomor);
            },
          ),
        ],
      ),

      // Modul Tracking
      GoRoute(
        path: '/tracking-penawaran',
        name: 'tracking-penawaran',
        builder: (context, state) => const TrackingPenawaranScreen(),
      ),
      GoRoute(
        path: '/tracking-map',
        name: 'tracking-map',
        builder: (context, state) => const TrackingMapScreen(),
      ),
      GoRoute(
        path: '/tracking-spk',
        name: 'tracking-spk',
        builder: (context, state) => const TrackingSpkScreen(),
      ),

      // Modul Permintaan Harga
      GoRoute(
        path: '/permintaan-harga',
        name: 'permintaan-harga',
        builder: (context, state) => const PermintaanHargaListScreen(),
        routes: [
          GoRoute(
            path: 'kalkulasi',
            name: 'permintaan-harga-kalkulasi',
            builder: (context, state) => const PermintaanHargaFormScreen(),
          ),
          GoRoute(
            path: ':nomor',
            name: 'permintaan-harga-detail',
            builder: (context, state) {
              final nomor = state.pathParameters['nomor'] ?? '';
              return PermintaanHargaDetailScreen(nomor: nomor);
            },
          ),
        ],
      ),

      // Modul Potensi
      GoRoute(
        path: '/potensi',
        name: 'potensi',
        builder: (context, state) => const PotensiScreen(),
      ),

      // Modul Achievement
      GoRoute(
        path: '/achievement',
        name: 'achievement',
        builder: (context, state) => const AchievementScreen(),
      ),

      // Modul Kurir
      GoRoute(
        path: '/kurir',
        name: 'kurir',
        builder: (context, state) => const KurirMenuScreen(),
      ),

      // Ganti Password
      GoRoute(
        path: '/ganti-password',
        name: 'ganti-password',
        builder: (context, state) => const GantiPasswordScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Halaman tidak ditemukan: ${state.uri}'),
      ),
    ),
  );
});
