import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/prefs.dart';

/// Fondasi freemium NOL-RUPIAH: status Pro disimpan lokal (tanpa server).
///
/// Alur uang termurah untuk app gratis:
/// 1. Donasi (Saweria/Trakteer/QRIS) → user kirim bukti → kamu kasih kode.
/// 2. Kode donasi dibuka di paywall → [unlock] → Pro selamanya di HP itu.
/// 3. Nanti (kalau ada traction): ganti [unlock] dengan Google Play
///    In-App Purchase tanpa ubah UI paywall — provider ini yang diganti.
///
/// TODO SEBELUM RILIS:
/// - Ganti [donateUrl] dengan link Saweria/Trakteer/QRIS kamu (1 baris).
/// - [storeUrl] mengarah ke GitHub Releases sampai app terbit di Play
///   Store (link Play sekarang masih 404) — ganti ke link Play saat rilis.
/// - Ganti [donorCodes] dengan kode acak kamu sendiri.
const donateUrl = 'https://saweria.co/TODO-GANTI-USERNAME';
const storeUrl = 'https://github.com/ApipppX/cycling_coach/releases';
const shareText =
    'Coba CyclingCoach — pelatih sepeda pribadi + GPS ala Strava, gratis! Download: $storeUrl';

/// Kode donasi demo. Format bebas; cocokkan case-insensitive, spasi diabaikan.
const donorCodes = <String>{'GOWES-PRO-2026', 'TERIMAKASIH'};

String normalizeCode(String s) =>
    s.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');

bool isValidDonorCode(String s) => donorCodes.contains(normalizeCode(s));

/// Keuntungan Pro yang dijanjikan di paywall. Semua item di bawah ini
/// SUDAH diimplementasikan (bukan janji kosong):
/// - 'pdf': laporan PDF tanpa footer promo.
/// - 'map': gaya peta gelap (Dark Matter) di Jelajah + Rekam.
/// - 'badge': lencana PRO di Profil.
const proPerks = <String>[
  'Laporan PDF bersih tanpa footer promo',
  'Gaya peta Gelap untuk gowes malam',
  'Lencana PRO + prioritas request fitur',
];

class PremiumState {
  final bool isPro;
  const PremiumState({this.isPro = false});
}

class PremiumNotifier extends Notifier<PremiumState> {
  SharedPreferences get _p => ref.read(sharedPrefsProvider);

  @override
  PremiumState build() {
    final p = ref.watch(sharedPrefsProvider);
    return PremiumState(isPro: p.getBool('is_pro') ?? false);
  }

  /// Buka kunci Pro dengan kode donasi. Kembalikan true bila kode valid.
  Future<bool> unlock(String code) async {
    if (!isValidDonorCode(code)) return false;
    await _p.setBool('is_pro', true);
    state = const PremiumState(isPro: true);
    return true;
  }

  Future<void> lock() async {
    await _p.setBool('is_pro', false);
    state = const PremiumState(isPro: false);
  }
}

final premiumProvider =
    NotifierProvider<PremiumNotifier, PremiumState>(PremiumNotifier.new);
