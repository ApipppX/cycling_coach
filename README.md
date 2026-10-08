# CyclingCoach — Strava-like GPS Cycling Coach (Flutter, offline-first)

Pelatih sepeda pribadi + **perekam GPS ala Strava**: peta live OpenStreetMap,
auto-pause, rute tersimpan per sesi, ekspor GPX, analisis beban sport-science
(TRIMP / CTL / ATL / TSB), Coach AI harian, planner event, statistik, dan laporan PDF.

## Fitur

- **Beranda**: target mingguan, riwayat + cari/sort/hapus massal, badge 🗺 GPS,
  impor & contoh CSV, tombol **Rekam GPS** + **Manual**.
- **Rekam GPS** (baru, Strava-like):
  - Peta live **OpenStreetMap via `flutter_map`** (stack yang sama dengan Leaflet.js di web:
    `TileLayer` + `PolylineLayer` + `MarkerLayer`).
  - Stats live: jarak, waktu, kecepatan kini, elevasi gain, akurasi ±m.
  - **Auto-pause** saat diam (lampu merah), filter anti GPS-jump, akurasi buruk dibuang.
  - Start → Jeda/Lanjut → Selesai → dialog simpan (nama/HR/catatan) → masuk DB + evaluasi sesi.
  - Rute disederhanakan (Douglas-Peucker ±4 m) agar DB ringan, tetap start/finish akurat.
- **Detail sesi**: tile Jarak/Durasi/Avg/**Max speed**/Elevasi±/**Kalori**,
  **grafik profil elevasi** (smoothed, min/max), **split per km** (waktu, kec,
  elev), peta rute (pin start hijau + finish), tombol **Bagikan GPX**
  (impor ke Strava/Garmin), durasi real GPS, TRIMP, evaluasi sesi.
- **Coach AI**: rekomendasi hari ini (rest/easy/interval/tempo/long/taper/event),
  CTL/ATL/TSB, freshness, mix sesi, peringatan overreach/monotoni/deload.
- **Statistik**: lifetime totals, grafik 8 minggu / 6 bulan / 3 tahun, tren,
  distribusi zona HR, rekor & streak.
- **Event**: kesiapan %, plan harian + progres, kalkulator ETA Anti-COT + timer live.
- **Profil**: nama/umur/berat/target, MaxHR, tema, backup/restore JSON (termasuk rute GPS), hapus data.

## Cara pakai GPS (Strava-like)

1. Buka tab **Rekam** (atau tombol **Rekam GPS** di Beranda).
2. Izinkan **Location → While Using** saat diminta. Nyalakan GPS HP.
3. Tunggu chip akurasi `±… m` kecil (<15 m ideal), tekan **Mulai Rekam**.
4. Gowes. Peta mengikuti (tombol 🎯 untuk on/off follow). Diam = auto-pause.
5. **Jeda** bila istirahat warung, **Lanjut** setelahnya, **Selesai** di finish.
6. Isi nama/HR/catatan → **Simpan**. Sesi muncul di Beranda dengan badge 🗺 GPS;
   buka Detail untuk peta + ekspor GPX.

> Keterbatasan v1: tracking **foreground-only** (seperti Strava tanpa background
> service). Biarkan app di depan; kunci layar lama di sebagian HP bisa
> menghentikan update GPS OS. Background service direncanakan v2.

## Panduan lengkap (dari nol sampai bisa)

### A. Install & jalan pertama kali — dari mana ke mana

| Dari (kondisi) | Ke (hasil) | Caranya |
|---|---|---|
| Belum ada Flutter | Flutter 3.47+ terpasang | Ikuti [flutter.dev/install](https://flutter.dev/install), lalu `flutter doctor` |
| Repo baru di-clone | Depedensi siap | `flutter pub get` |
| Tabel DB berubah | Kode Drift regenerasi | `dart run build_runner build` |
| Kode siap dites | Yakin tak ada error | `flutter analyze` (harus No issues) + `flutter test` (33 hijau) |
| Mau coba di HP | App jalan di Android | Colok HP (USB debugging ON) → `flutter run` → pilih device |
| Tak ada HP | Coba di laptop | `flutter run` → pilih **Chrome** (peta + DB jalan; GPS = lokasi kasar browser) atau **Windows** (butuh Developer Mode ON untuk symlink plugin) |
| Buka app pertama kali | Onboarding selesai | Isi nama + umur → MaxHR otomatis `220−umur` → masuk Beranda |

### B. Rekam gowes pakai GPS — langkah demi langkah

Beranda → **Rekam GPS** (atau tab **Rekam**): tekan **Mulai Rekam** → gowes →
**Jeda** saat istirahat → **Lanjut** → **Selesai** → isi nama/HR/catatan (kalori
& elevasi sudah dihitung otomatis) → **Simpan**. Hasilnya:

- Masuk riwayat Beranda dengan badge 🗺 GPS,
- Detail berisi **tile statistik + grafik elevasi + split/km + peta + GPX**,
- Otomatis masuk hitungan Coach (TRIMP/CTL/ATL/TSB), Statistik, dan PDF.

### C. Catat manual / impor CSV — apa ke apa

- **Manual**: tombol **Manual** → isi 2 dari 3 (jarak, durasi, kecepatan) →
  sisanya otomatis → Simpan & Evaluasi.
- **CSV**: Beranda → **Impor CSV**. Format header:
  `id,nama,tanggal,jarak_km,elevasi_m,kecepatan_kmh,hr_bpm,catatan`
  (HR & catatan boleh kosong; file contoh via **Contoh CSV**). CSV = ringkasan
  tanpa rute — rute hanya dari rekaman GPS / restore JSON.
- **Contoh baris**: `,Gowes Pagi,2026-09-01,25.50,150,25.0,140,"Rute biasa"`

### D. Backup / restore — kapan pakai apa

| Mau apa | Ke mana | Caranya |
|---|---|---|
| Simpan cadangan | Beranda Profil → **Backup (JSON)** → file dishare (WA/GDrive) | Berisi latihan + event + pengaturan, **termasuk rute GPS** |
| Pindah HP / balikkan data | Profil → **Restore (JSON)** → pilih file → **Timpa** | Menimpa SEMUA data sekarang; backup lama (tanpa rute) tetap bisa direstore |
| Pindah ke Strava/Garmin | Detail sesi GPS → **Bagikan GPX** | File `.gpx` standar, tinggal upload |
| Laporan ke pelatih | Coach AI → **Bagikan Laporan PDF** | Ringkasan 7 hari + CTL/ATL/TSB + zona + sesi GPS |

### E. Event & Anti-COT — alur hari-H

Tab **Event** → isi nama + tanggal + target km → lihat **kesiapan %** + plan
harian (centang progres) → hari-H buka kalkulator **Anti-COT**: isi target,
COT, jam start, lalu tiap pos update KM + **HITUNG** (verdict AMAN/WASPADA/OVER
+ pace dibutuhkan + tabel checkpoint). Nyalakan **Timer live** agar waktu
berjalan sendiri.

## Troubleshooting (masalah → sebab → obat)

| Gejala | Sebab umum | Obat |
|---|---|---|
| Layar putih di Chrome + error `web parameter needs to be set` | `web/sqlite3.wasm` / `drift_worker.js` hilang | File wajib ada (dari release drift = `pubspec.lock`); jangan hapus folder `web/` |
| `Type 'X' not found` setelah `pub get` | Cache compiler basi | `flutter clean` → `flutter pub get` → run lagi |
| Peta abu-abu / tile tak muncul | Offline / tile OSM diblokir | Nyalakan internet; OSM butuh koneksi saat lihat peta (rute GPS tetap terekam offline) |
| GPS tak dapat fix / akurasi besar | Di dalam gedung / GPS HP mati | Keluar ruangan, nyalakan Location, tunggu chip `±… m` < 15 |
| `Izin lokasi ditolak` | Permission denied / forever | Settings → Apps → CyclingCoach → Location → Allow (jangan "Ask every time") |
| Rekaman berhenti saat layar mati | Foreground-only v1 | Biarkan app di depan; matikan battery-optimization untuk app ini |
| `Building with plugins requires symlink` (Windows) | Developer Mode mati | `start ms-settings:developers` → Developer Mode **ON** |
| Grafik elevasi "Tanpa data" | GPS tak memberi altitude (mis. browser) | Wajar — jarak & peta tetap benar; di HP asli ada datanya |
| Angka kalori/TRIMP "aneh" | Tanpa HR / berat belum diisi | Isi berat di Profil + pakai HR monitor; tanpa HR = estimasi dari jarak |

## Stack & cara kerja

| Lapisan | Teknologi | Peran |
|---|---|---|
| UI | Flutter 3 + Material 3, Riverpod | 6 tab (`home_shell.dart` + `IndexedStack` agar state tab tidak hilang) |
| Peta | `flutter_map` ^7 + `latlong2` (tiles `tile.openstreetmap.org`) | Render OSM — setara Leaflet.js (`TileLayer`/`PolylineLayer`/`MarkerLayer`). Atribusi OSM wajib tampil |
| GPS | `geolocator` ^13 (`bestForNavigation`, `distanceFilter: 5 m`) | Stream posisi foreground + izin lokasi + cek service |
| DB lokal | **Drift (SQLite)** via `drift_flutter`, migrasi **v6** | Tabel `cycling_activities` (+`route_json`, `duration_sec`), `event_goals`, `plan_checks`. Offline-first, reactive `watch()` |
| Prefs | `SharedPreferences` | target mingguan, MaxHR, profil, berat, tema, onboarded |
| Grafik | `fl_chart` | Bar/line statistik |
| Laporan | `pdf` + `share_plus` + `path_provider` | PDF mingguan + share CSV/JSON/GPX |
| Util | `intl`, `file_picker`, `path`, `flutter_animate` | Format, impor, path, animasi |

### Alur data GPS (ujung ke ujung)

```
geolocator stream → track_recorder.dart (filter+jarak+elevasi+auto-pause)
  → TrackState (Riverpod) → track_screen.dart (LiveTrackMap + stats)
  → finish() → simplifyRoute() → encodeRoute() → Drift upsertActivity()
  → watchActivities() → Beranda / Detail (RouteMap decode) / Coach / Stats
  → shareGpx() via buildGpx() / backup JSON (routeJson ikut)
```

### Database (Drift SQLite, file `cycling_coach_database`)

- `cycling_activities`: `id, name, distance (m), total_elevation_gain (m),`
  `average_speed (m/s), start_date (ISO), average_heart_rate, note,`
  **`route_json` (TEXT `[[lat,lng,ele,t],…]`, `''` = manual),**
  **`duration_sec` (REAL, `0` = hitung dari jarak/kecepatan)**.
- `event_goals`: `id, name, event_date, target_distance_km, target_elevation_m, created_at`
  (satu event aktif: `saveSingleEvent` menimpa).
- `plan_checks`: `date (PK yyyy-MM-dd)` — checklist manual plan event.
- Migrasi: v3→v4 `note`, v4→v5 drop `rpe`, **v5→v6 tambah `route_json` +
  `duration_sec` (try/catch agar upgrade parsial aman)**. Regenerasi:
  `dart run build_runner build`.
- Web (Chrome/Edge): SQLite berjalan via WASM — `web/sqlite3.wasm` +
  `web/drift_worker.js` **wajib ada** (diambil dari release drift yang sama
  dengan `pubspec.lock`: drift 2.35.1; `DriftWebOptions` di `app_database.dart`).
  Jangan upgrade `drift` tanpa mengunduh ulang kedua file itu.

## File-by-file (lib/src)

```
main.dart                    → init SharedPrefs + Drift, inject via Riverpod overrides.
models/models.dart           → POJO CyclingActivity (+routeJson/durationSec/hasRoute),
                               GpsPoint (lat/lng/ele/t), EventGoal, msToKmh helpers.
data/app_database.dart       → Drift schema v6 + migrasi + CRUD/watch/restoreAll.
                               (app_database.g.dart = GENERATED, jangan edit manual.)
data/prefs.dart              → PrefsState + PrefsNotifier (target/MaxHR/profil/berat/tema).
core/geo_utils.dart          → Matematika GPS murni: haversine, filterRawPoints
                               (buang akurasi>25 m & jump>80 km/h), routeDistanceM,
                               routeElevationGain/Loss (step ≥2 m), maxSpeedMs
                               (anti-noise), elevationSamples (smoothed, ≤120),
                               computeSplits (per km + ekor), simplifyRoute
                               (Douglas-Peucker), encode/decodeRoute (JSON ringkas),
                               buildGpx (GPX 1.1), movingAvgKmh. Semua dites.
core/track_recorder.dart     → NEW. Notifier rekaman: locating/recording/paused/
                               finished/error, ticker detik, auto-pause, toActivity().
core/coach_engine.dart       → TRIMP/CTL/ATL/TSB, freshness, plan harian, readiness
                               event, plan generator, evaluasi sesi, statistik periode.
                               (durationMinOf kini utamakan durationSec GPS.)
core/health_stats.dart       → Estimasi kalori + lifetimeTotals.
core/csv_utils.dart          → Build/parse CSV riwayat (kompat 7/8/9 kolom legacy).
core/backup.dart             → Export/import JSON v1 (activities+events+prefs;
                               activities kini bawa routeJson+durationSec).
core/eta_predictor.dart      → Kalkulator Anti-COT: proyeksi finis, pace dibutuhkan,
                               verdict AMAN/WASPADA/OVER, checkpoint per X km.
core/report_pdf.dart         → PDF mingguan (ringkasan 7 hari, CTL/ATL/TSB, zona,
                               sesi, rekomendasi; kini ada baris "Sesi GPS").
providers/providers.dart     → dbProvider, activities/events/planChecks streams,
                               coachAnalysisProvider (dihitung sekali per perubahan).
ui/app.dart                  → MaterialApp + tema + onboarding gate.
ui/theme/app_theme.dart      → Light/dark, spacing, warna Strava-ish.
ui/screens/home_shell.dart   → 6 tab: Beranda/Rekam/Coach/Statistik/Event/Profil
                               (Rail di lebar ≥600, Bar di HP).
ui/screens/dashboard_screen → Target, search/sort/hapus massal, CSV, kartu riwayat
                               (+badge GPS), FAB ganda Rekam GPS/Manual.
ui/screens/track_screen.dart → NEW. Layar Rekam: LiveTrackMap, chip status+akurasi,
                               stats live, kontrol Start/Jeda/Selesai, _SaveDialog
                               (tulis Drift), shareGpx() helper.
ui/screens/session_screens.dart → Detail (tile Jarak/Durasi/Avg/Max/Elev±/kkal +
                               ElevProfileChart + Split/km + RouteMap + GPX +
                               tabel metrik + catatan) & Evaluasi sesi.
ui/screens/coach_screen.dart → Kartu sesi berikutnya + kondisi tubuh + warning + PDF.
ui/screens/stats_screen.dart → Total + 3 grafik + tren + zona + rekor + streak.
ui/screens/event_screen.dart → Goal + readiness + plan + progres + ETA Anti-COT.
ui/screens/eta_predictor_screen.dart → Kalkulator COT standalone + timer live.
ui/screens/profile_screen.dart → Profil, MaxHR, tema, backup/restore, hapus data.
ui/screens/onboarding_screen.dart → Nama+umur → MaxHR otomatis (220-umur).
ui/widgets/route_map.dart    → RouteMap (riwayat, auto-bounds + pin start/finish
                               + atribusi OSM) & LiveTrackMap (ikuti posisi).
ui/widgets/elev_chart.dart   → NEW. ElevProfileChart ala Strava (area + min/max
                               + tooltip km/m; placeholder bila tanpa altitude).
ui/widgets/activity_form.dart → Dialog tambah/edit (jarak/durasi/kecepatan saling
                               isi; edit TIDAK menghapus routeJson GPS).
ui/widgets/common.dart       → SectionTitle, AppTextField, AppSectionCard, AppButton,
                               showAppConfirm, showAppSnack, EmptyState, AppLoading,
                               AppError, AppStatsGrid, StatTile, ScrollTable.
ui/widgets/charts.dart / perf_chart.dart → Bar & garis performa.
ui/widgets/metric_hero.dart / zone_chip.dart → Hero target + avatar zona HR.
ui/widgets/responsive.dart   → Breakpoints + ResponsiveList/TwoColumn.
```

## Audit weirdness (diperiksa & diperbaiki)

- [x] **AndroidManifest tanpa izin lokasi** → tambah `FINE/COARSE_LOCATION` + feature GPS.
- [x] **Info.plist tanpa kunci lokasi** → tambah `NSLocationWhenInUse`,
      `AlwaysAndWhenInUse`, `NSMotionUsage` (auto-pause).
- [x] **Edit sesi GPS menghapus rute** → `activity_form` kini pertahankan
      `routeJson`/`durationSec` saat edit.
- [x] **Durasi GPS diabaikan** → `durationMinOf` + `durationMin` utamakan
      `durationSec` (pauses ikut); TRIMP/kalori/statistik otomatis benar.
- [x] **Backup buang rute** → `backup.dart` bawa `routeJson`+`durationSec`
      (backup lama tetap terbaca via default).
- [x] **PDF tak sebut GPS** → baris "Sesi GPS n/m dengan peta rute".
- [x] **Lint** (`library_private_types_in_public_api`, unused import/var/param)
      → `RawGpsFix` publik, import dibersihkan, `analyze` = **No issues**.
- [x] **Detail tanpa peta** → `RouteMap` + ekspor GPX; riwayat ada badge 🗺 GPS.
- [x] **Geo edge-cases** → `decodeRoute` tak pernah throw (return `[]`);
      guard 20.000 titik; XML-escape GPX; clamp lat/lng/ele.

## Perintah

```powershell
flutter pub get
dart run build_runner build   # regenerasi Drift bila tabel berubah
flutter analyze                # harus: No issues found!
flutter test                   # 33 tes (21 lama + 12 GPS) harus hijau
flutter run -d emulator-5554  # GPS: pakai HP fisik / emulator dengan mock route
```

GPX di emulator: Android Emulator → ⋯ → Location → Routes/Play untuk simulasi
gerak; iOS Simulator → Features → Location → City Run.

## Skema versi & kompatibilitas

- DB `schemaVersion = 6`. Downgrade tidak didukung (fresh install bila perlu).
- Backup JSON `version: 1` (field rute opsional → backup lama tetap restore).
- CSV tidak membawa rute (by design — CSV = ringkasan; rute via GPX/JSON).
- Atribusi peta: **© OpenStreetMap contributors** (wajib lisensi ODbL).

## Catatan build

- Gradle: tambah `--enable-native-access=ALL-UNNAMED` ke `org.gradle.jvmargs`
  dan `GRADLE_OPTS` untuk menekan warning JDK 27 (`native-platform`).
- Estimasi kalori & TRIMP tanpa HR bersifat perkiraan, bukan pengukuran lab.
- Jarak GPS = Haversine per segmen tersaring; elevasi = gain dengan step ≥2 m
  (noise barometer diabaikan); kecepatan = jarak/waktu elapsed (jeda ikut).
