# CyclingCoach — Strava-like GPS Cycling Coach (Flutter, offline-first)

Pelatih sepeda pribadi + **perekam GPS ala Strava**: peta live OpenStreetMap,
auto-pause, rute tersimpan per sesi, ekspor GPX, analisis beban sport-science
(TRIMP / CTL / ATL / TSB), Coach AI harian, planner event, statistik, dan laporan PDF.

## Fitur

- **Beranda**: target mingguan, riwayat + cari/sort (Terbaru/Terjauh/Tercepat)/
  hapus massal, badge 🗺 GPS, impor & contoh CSV, speed-dial **Rekam GPS** +
  **Manual** + **Impor CSV**.
- **Rekam GPS** (Strava-like, **background service v2 — tetap jalan saat
  layar mati / app di-background**):
  - Peta live **OpenStreetMap via `flutter_map`** (stack yang sama dengan Leaflet.js di web:
    `TileLayer` + `PolylineLayer` + `MarkerLayer`).
  - Stats live **otomatis**: jarak, waktu total, kecepatan kini, **elevasi gain**,
    **Max (km/h)**, **Avg gerak (km/h)**, akurasi ±m, jumlah titik + jam mulai.
  - **Auto-pause** saat diam (lampu merah), filter anti GPS-jump, akurasi buruk dibuang.
  - Foreground service Android (`location` type) + notifikasi permanen
    `● Merekam … km` — **boleh kunci layar / buka app lain**.
  - **Backup anti-hilang** tiap ~15 dtk/50 titik ke disk: bila HP mati / OS
    membunuh service, buka tab Rekam → **Pulihkan rekaman terputus** (paused)
    → Lanjut atau Selesai+Simpan. Data tidak hilang total.
  - Bila service dibunuh tapi titik sudah ada: banner error menawarkan
    **Simpan Hasil (X km)** langsung, bukan cuma "Rekam Lagi".
  - Start → Jeda/Lanjut → Selesai → dialog simpan (nama/HR/catatan,
    kalori otomatis) → masuk DB + evaluasi sesi.
  - Rute disederhanakan (Douglas-Peucker ±4 m) agar DB ringan, tetap start/finish akurat.
- **Detail sesi** (semua otomatis dari rute, tanpa input): tile Jarak/Durasi total/
  **Waktu gerak**/Avg/**Avg gerak**/**Max + KM tercepat**/Elevasi naik±turun/**Kalori**,
  banner **⚡ Terkencang KM X**, **grafik profil elevasi** (smoothed, min/max),
  **split per km** (KM tercepat di-highlight ⚡), peta rute (pin start hijau +
  finish), tombol **Bagikan GPX** (impor ke Strava/Garmin), durasi real GPS,
  TRIMP, evaluasi sesi.
- **Jelajah** (pengganti GMaps, tanpa API key): kolom **Dari** (default
  **Posisi saya**) + **Ke**, tukar ⇅, tap peta + reverse-geocode nama jalan,
  rute sepeda OSRM bicycle + fallback FOSSGIS, **Mulai** (navigasi in-app:
  follow + sisa jarak/ETA + auto-sampai), **Rekam**, **GPX**, **Ulangi**,
  **GMaps** eksternal. Lihat §C2.
- **CyclingCoach Pro** (nol-rupiah via kode donasi di paywall): PDF bersih
  tanpa footer promo, gaya peta Gelap untuk gowes malam (Rekam + Jelajah),
  lencana PRO di Profil. Inti app (rekam/coach/statistik) tetap gratis.
- **Coach AI**: rekomendasi hari ini (rest/easy/interval/tempo/long/taper/event),
  CTL/ATL/TSB, freshness, mix sesi, peringatan overreach/monotoni/deload.
- **Statistik**: lifetime totals, grafik 8 minggu / 6 bulan / 3 tahun, tren,
  distribusi zona HR, rekor & streak.
- **Event**: **Kesiapan: %**, **Progres plan**, **Jadwal latihan**, tombol
  **Kalkulator ETA Anti-COT** + Timer live.
- **Profil**: nama/umur/berat/target, MaxHR, tema, **CyclingCoach Pro**,
  backup/restore JSON (termasuk rute GPS), bagikan app, hapus data.

## Cara pakai GPS (Strava-like, background)

1. Buka tab **Rekam** (atau tombol **Rekam GPS** di Beranda).
2. Izinkan **Location** saat diminta, lalu setujui **Allow all the time /
   Selalu izinkan** + **Notifikasi** (diminta otomatis saat Mulai Rekam).
   Nyalakan GPS HP.
3. Tunggu chip akurasi `±… m` kecil (<15 m ideal), tekan **Mulai Rekam**.
   Muncul notifikasi permanen `● Merekam … km` = service latar hidup.
4. Gowes. Peta mengikuti (tombol lokasi untuk on/off follow). Diam = auto-pause.
   **Boleh kunci layar / buka WA / kantongi HP** — rekaman tetap jalan.
5. **Jeda** bila istirahat warung, **Lanjut** setelahnya, **Selesai** di finish.
6. Isi nama/HR/catatan (jarak/waktu/elevasi/kalori/max/avg-gerak sudah
   otomatis) → **Simpan**. Sesi muncul di Beranda dengan badge 🗺 GPS;
   buka Detail untuk peta + banner Terkencang + ekspor GPX.
7. **HP Xiaomi/Oppo/Vivo masih putus?** Di layar Rekam ketuk
   **Buka Pengaturan** → Battery → *No restrictions / Jangan optimalkan* +
   kunci app di Recent (🔒). Ini perilaku OS, bukan bug app.
8. **HP mati / app dibunuh tiba-tiba?** Buka lagi tab Rekam →
   **Pulihkan rekaman terputus** (atau banner error → **Simpan Hasil**).
   Backup ditulis tiap ~15 dtk, maksimal rugi 15 dtk terakhir.

> v2: tracking memakai **foreground service** (`track_service.dart`), bukan
> foreground-only. Elapsed dihitung di service sehingga akurat walau UI
> dibekukan OS saat layar mati. Jeda manual benar-benar menghentikan jarak.

## Panduan lengkap (dari nol sampai bisa)

### A. Install & jalan pertama kali — dari mana ke mana

| Dari (kondisi) | Ke (hasil) | Caranya |
|---|---|---|
| Belum ada Flutter | Flutter 3.47+ terpasang | Ikuti [flutter.dev/install](https://flutter.dev/install), lalu `flutter doctor` |
| Repo baru di-clone | Depedensi siap | `flutter pub get` |
| Tabel DB berubah | Kode Drift regenerasi | `dart run build_runner build` |
| Kode siap dites | Yakin tak ada error | `flutter analyze` (harus No issues) + `flutter test` (44 hijau) |
| Mau coba di HP | App jalan di Android | Colok HP (USB debugging ON) → `flutter run` → pilih device |
| Tak ada HP | Coba di laptop | `flutter run` → pilih **Chrome** (peta + DB jalan; GPS = lokasi kasar browser) atau **Windows** (butuh Developer Mode ON untuk symlink plugin) |
| Buka app pertama kali | Onboarding selesai | Isi nama + umur + berat → preview `MaxHR otomatis: X bpm` (`220−umur`) → **Mulai Berlatih** → Beranda |

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

### C2. Cari rute & navigasi (tab Jelajah — pengganti GMaps, tanpa API key)

Tab **Jelajah** = GMaps mini khusus sepeda, semua gratis tanpa key
(peta OSM + cari Nominatim + rute OSRM profil bicycle):

1. Kolom **Dari** otomatis = **Posisi saya** (tombol 📍 untuk isi ulang);
   kolom **Ke** = ketik nama tempat / jalan / kota, atau **tap peta**
   (chip di atas peta nunjukin tap mengisi Dari atau Tujuan — ketuk ikon
   pin di tiap kolom untuk ganti target; tap jalan langsung jadi nama
   jalan via reverse-geocode).
2. Tombol **⇅** menukar Dari–Tujuan; **🧹** membersihkan.
3. Rute sepeda **ramah gowes** (profil bicycle: hindari tol/motorway)
   otomatis digambar + jarak & estimasi waktu. Server primer OSRM,
   fallback FOSSGIS bila primer down.
4. **Mulai** = navigasi DI DALAM app (peta mengikuti posisimu, banner sisa
   jarak + ETA live, berhenti otomatis saat sampai <40 m, tombol **Berhenti**
   untuk batal). Tak perlu GMaps.
5. **Rekam** = buka layar Rekam GPS (catat gowes sambil ikuti rute).
6. **GPX** = bagikan rute rencana (impor ke Strava/Garmin/head unit).
7. **Ulangi** = hitung ulang rute; **GMaps** = buka rute di Google Maps
   (opsi eksternal bila butuh turn-by-turn suara).

### D. Backup / restore — kapan pakai apa

| Mau apa | Ke mana | Caranya |
|---|---|---|
| Simpan cadangan | Beranda Profil → **Backup (JSON)** → file dishare (WA/GDrive) | Berisi latihan + event + pengaturan, **termasuk rute GPS** |
| Pindah HP / balikkan data | Profil → **Restore (JSON)** → pilih file → **Timpa** | Menimpa SEMUA data sekarang; backup lama (tanpa rute) tetap bisa direstore |
| Pindah ke Strava/Garmin | Detail sesi GPS → **Bagikan GPX** | File `.gpx` standar, tinggal upload |
| Laporan ke pelatih | Coach AI → **Bagikan Laporan PDF** | Ringkasan 7 hari + CTL/ATL/TSB + zona + sesi GPS |

### E. Event & Anti-COT — alur hari-H

Tab **Event** → isi nama + tanggal + target km → lihat **Kesiapan: %** +
**Progres plan** + **Jadwal latihan (N hari)** (centang progres) → hari-H buka
tombol **Kalkulator ETA Anti-COT**: isi target, COT, jam start, lalu tiap pos
update KM + **HITUNG PREDIKSI** (verdict AMAN/WASPADA/OVER + pace dibutuhkan +
tabel checkpoint). Nyalakan **Timer live** (jadi **Live ON**) agar waktu
berjalan sendiri tiap 30 dtk.

## Troubleshooting (masalah → sebab → obat)

| Gejala | Sebab umum | Obat |
|---|---|---|
| Layar putih di Chrome + error `web parameter needs to be set` | `web/sqlite3.wasm` / `drift_worker.js` hilang | File wajib ada (dari release drift = `pubspec.lock`); jangan hapus folder `web/` |
| `Type 'X' not found` setelah `pub get` | Cache compiler basi | `flutter clean` → `flutter pub get` → run lagi |
| Peta abu-abu / tile tak muncul | Offline / tile OSM diblokir | Nyalakan internet; OSM butuh koneksi saat lihat peta (rute GPS tetap terekam offline) |
| Tile putih tulisan "API KEY REQUIRED" diagonal | Server CARTO kini wajib API key berbayar | Sudah diperbaiki: app kini pakai tile OSM murni tanpa key (primer `tile.openstreetmap.org` + fallback HOT). Update ke versi ini |
| Rute sepeda tak ditemukan di Jelajah | Server OSRM primer down / jalan tak tersambung | App otomatis coba server fallback FOSSGIS (`routing.openstreetmap.de/routed-bike`); bila dua-duanya gagal coba titik lain yang di jalan raya |
| GPS tak dapat fix / akurasi besar | Di dalam gedung / GPS HP mati | Keluar ruangan, nyalakan Location, tunggu chip `±… m` < 15 |
| `Izin lokasi ditolak` | Permission denied / forever | Settings → Apps → CyclingCoach → Location → Allow + notifikasi ON |
| Rekaman berhenti saat layar mati (Xiaomi/Oppo/Vivo) | OS membunuh service walau foreground | Layar Rekam → **Buka Pengaturan** → Battery *No restrictions*; kunci app di Recent 🔒; izin Location = *Allow all the time* |
| Banner "Pelacakan latar berhenti" tapi ada jarak | OS membunuh service di tengah jalan | **Jangan panik — data aman**: ketuk **Simpan Hasil (X km)** di banner/tombol, atau **Pulihkan rekaman terputus** bila app sempat mati total |
| Sinyal GPS terputus >30 dtk | GPS HP mati / di basement | Nyalakan GPS, keluar ruangan; banner hilang otomatis saat fix masuk lagi |
| Area abu-abu kosong di Beranda HP | Bug lama `Flexible` di dalam `Wrap` (sudah diperbaiki) | Update ke versi ini; bila masih: `flutter clean` → run ulang. Bar Contoh CSV kini `Row+Expanded` yang legal |
| `Building with plugins requires symlink` (Windows) | Developer Mode mati | `start ms-settings:developers` → Developer Mode **ON** |
| Grafik elevasi "Tanpa data" | GPS tak memberi altitude (mis. browser / HP tanpa barometer fix) | Wajar — jarak & peta tetap benar; di HP outdoor ada datanya. Detail tetap tunjukkan gain/loss/split/max |
| Angka kalori/TRIMP "aneh" | Tanpa HR / berat belum diisi | Isi berat di Profil + pakai HR monitor; tanpa HR = estimasi dari jarak |
| Impor CSV/Restore tak bereaksi | User tekan Batal pada file picker | Normal — Batal = diam (v13 kembalikan list kosong, bukan crash). Pilih file `.csv`/`.json` untuk lanjut |
| Share CSV/JSON/GPX gagal di HP | Folder temp tak bisa ditulis | Sudah pakai `path_provider.getTemporaryDirectory()` (bukan `Directory.systemTemp`); coba lagi + pastikan storage tidak penuh |

## Stack & cara kerja

| Lapisan | Teknologi | Peran |
|---|---|---|
| UI | Flutter 3 + Material 3, Riverpod | 7 tab (`home_shell.dart` + `IndexedStack` lazy agar Beranda instant di HP kentang) |
| Peta | `flutter_map` 8.3.2 + `latlong2` (murni OSM tanpa key: primer `tile.openstreetmap.org` + fallback HOT `tile.openstreetmap.fr/hot`; gelap via `darkModeTileBuilder` bawaan) | Render OSM — template persis Leaflet.js `L.tileLayer` (`TileLayer`/`PolylineLayer`/`MarkerLayer`). Atribusi `© OpenStreetMap contributors` wajib tampil |
| GPS | `geolocator` ^13 (`bestForNavigation`, `distanceFilter: 5 m`) + `flutter_background_service` ^5.1.0 (foreground `location`) + `permission_handler` | Stream di **isolate service** (tetap jalan layar mati) + izin WhileUsing/Always + notifikasi + `ignoreBatteryOptimizations` + backup disk anti-hilang |
| DB lokal | **Drift (SQLite)** via `drift_flutter`, migrasi **v6** | Tabel `cycling_activities` (+`route_json`, `duration_sec`), `event_goals`, `plan_checks`. Offline-first, reactive `watch()` |
| Prefs | `SharedPreferences` | target mingguan, MaxHR, profil, berat, tema, onboarded + **`track_backup_v1`** (sesi berjalan) |
| Grafik | `fl_chart` | Bar/line statistik + profil elevasi |
| Laporan | `pdf` + `share_plus` + `path_provider` (`getTemporaryDirectory`) | PDF mingguan + share CSV/JSON/GPX via temp dir yang benar di HP |
| Util | `intl`, `file_picker` v13 (`pickFiles()->List<PlatformFile>`), `path`, `flutter_animate` | Format, impor, path, animasi |

### Alur data GPS (ujung ke ujung, background)

```
geolocator stream (isolate service) → _BgEngine (filter+jarak+elevasi+auto-pause+elapsed wall-clock)
  → event 'pos' delta + 'full' sync → TrackRecorder (UI, Riverpod) → LiveTrackMap + stats live
  → backup disk tiap 15 dtk (track_backup_v1) → finish() → simplifyRoute(4 m) → encodeRoute()
  → Drift upsertActivity() → watchActivities() → Beranda / Detail (decode + max/moving/fastest/split/elev)
  → shareGpx() via buildGpx() / backup JSON (routeJson ikut)
HP mati/dibunuh → loadTrackBackup() → restoreInterrupted() (paused) → Lanjut / Selesai+Simpan
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
                               buildGpx (GPX 1.1), movingAvgKmh, **movingTimeSec
                               (waktu gerak), fastestSplit (KM tercepat),
                               eleMinMax (min–maks)**. Semua dites (44 tes).
core/track_service.dart        → Foreground service (isolate latar): _BgEngine
                               (elapsed wall-clock, jeda manual hentikan jarak,
                               notifikasi `● Merekam`, **backup disk
                               track_backup_v1 tiap 15 dtk/50 titik**,
                               save/load/clearTrackBackup).
core/track_recorder.dart     → Notifier rekaman (dual jalur BG + legacy):
                               locating/recording/paused/finished/error,
                               reattach via ping/pong+sync, **error pertahankan
                               titik (tawarkan Simpan, bukan buang)**,
                               **restoreInterrupted()/dryRun + openBatterySettings()**,
                               toActivity() (jarak+elevasi+avg otomatis).
core/coach_engine.dart       → TRIMP/CTL/ATL/TSB, freshness, plan harian, readiness
                               event, plan generator, evaluasi sesi, statistik periode.
                               (durationMinOf kini utamakan durationSec GPS.)
core/health_stats.dart       → Estimasi kalori + lifetimeTotals.
core/csv_utils.dart          → Build/parse CSV riwayat (kompat 7/8/9 kolom legacy).
core/backup.dart             → Export/import JSON v1 (activities+events+prefs;
                               activities kini bawa routeJson+durationSec).
core/premium.dart            → Pro nol-rupiah via kode donasi (cth `GOWES-PRO-2026`);
                               perks: PDF bersih, peta Gelap, lencana PRO. Dites.
core/eta_predictor.dart      → Kalkulator Anti-COT: proyeksi finis, pace dibutuhkan,
                               verdict AMAN/WASPADA/OVER, checkpoint per X km.
core/report_pdf.dart         → PDF mingguan (ringkasan 7 hari, CTL/ATL/TSB, zona,
                               sesi, rekomendasi; kini ada baris "Sesi GPS").
providers/providers.dart     → dbProvider, activities/events/planChecks streams,
                               coachAnalysisProvider (dihitung sekali per perubahan).
ui/app.dart                  → MaterialApp + tema + onboarding gate.
ui/theme/app_theme.dart      → Light/dark, spacing, warna Strava-ish.
ui/screens/home_shell.dart   → 7 tab: Beranda/Rekam/Jelajah/Coach AI/Statistik/Event/Profil
                               (Rail tablet; Bar HP: Coach, Stats. Lazy-IndexedStack
                               agar Beranda instant di HP kentang).
ui/screens/dashboard_screen → Target, search/sort/hapus massal, CSV, kartu riwayat
                               (+badge GPS), FAB ganda Rekam GPS/Manual.
                               FIX: Contoh-CSV kini Row+Expanded (bukan Wrap+Flexible
                               ilegal penyebab abu-abu di HP), share via
                               getTemporaryDirectory, picker v13 List<PlatformFile>.
ui/screens/explore_screen.dart → Jelajah ala GMaps TANPA key: kolom Dari+Ke
                               (cari Nominatim, Posisi saya, tukar, tap-peta
                               + reverse-geocode), rute sepeda OSRM bicycle
                               + fallback FOSSGIS, **navigasi in-app**
                               (follow + sisa jarak/ETA + auto-sampai),
                               GPX rencana (shareGpx), Rekam rute ini,
                               GMaps eksternal. Tile OSM key-free.
core/places_api.dart           → searchPlaces (Nominatim, UA wajib), fetchBikeRoute
                               (OSRM primer + fallback FOSSGIS, profil bicycle),
                               reverseGeocode (label jalan, fallback koordinat).
ui/screens/track_screen.dart → Layar Rekam: LiveTrackMap, chip status+akurasi,
                               banner error dengan **Simpan Hasil** + tombol
                               **Pulihkan rekaman terputus** + **Buka Pengaturan**
                               baterai, stats live (Jarak/Waktu/Kec/Elev-gain/
                               Max/Avg-gerak + caption titik), kontrol
                               Start/Jeda/Selesai, _SaveDialog (tulis Drift),
                               shareGpx() via temp dir.
ui/screens/session_screens.dart → Detail (**semua otomatis**: tile Jarak/Durasi total/
                               Waktu gerak/Avg/Avg-gerak/Max+KM/Elev naik+turun/
                               min–maks/kkal + banner ⚡ Terkencang + highlight
                               split tercepat + ElevProfileChart + Split/km +
                               RouteMap + GPX + tabel metrik + catatan) & Evaluasi.
ui/screens/coach_screen.dart → Kartu sesi berikutnya + kondisi tubuh + warning + PDF.
ui/screens/stats_screen.dart → Total + 3 grafik + tren + zona + rekor + streak.
ui/screens/event_screen.dart → Goal + readiness + plan + progres + ETA Anti-COT.
ui/screens/eta_predictor_screen.dart → Kalkulator COT standalone + timer live.
ui/screens/profile_screen.dart → Profil, MaxHR, tema, backup/restore, hapus data.
                               FIX: picker v13 + temp dir (seperti dashboard).
ui/screens/onboarding_screen.dart → Nama+umur → MaxHR otomatis (220-umur).
ui/widgets/route_map.dart    → osmTiles() SATU-SATUNYA sumber tile: primer
                               `tile.openstreetmap.org` + fallback HOT
                               (TANPA key — CARTO dibuang karena kini minta
                               API key), gelap via darkModeTileBuilder bawaan;
                               RouteMap + LiveTrackMap + zoom + MapOfflineHint.
ui/widgets/elev_chart.dart   → NEW. ElevProfileChart ala Strava (area + min/max
                               + tooltip km/m; placeholder bila tanpa altitude).
ui/widgets/activity_form.dart → Dialog **Tambah/Edit Latihan** (jarak/durasi/kecepatan saling
                               isi; tombol **Simpan & Evaluasi**; edit TIDAK menghapus routeJson GPS).
ui/widgets/pro_paywall.dart  → Bottom-sheet **CyclingCoach Pro** (manfaat + input kode
                               donasi + **Buka Pro**; gratis inti tetap jalan).
ui/widgets/common.dart       → SectionTitle, AppTextField, AppSectionCard, AppButton,
                               showAppConfirm, showAppSnack, EmptyState, AppLoading,
                               AppError, AppStatsGrid, StatTile, ScrollTable.
ui/widgets/charts.dart / perf_chart.dart → Bar & garis performa.
ui/widgets/metric_hero.dart / zone_chip.dart → Hero target + avatar zona HR.
ui/widgets/responsive.dart   → Breakpoints + ResponsiveList/TwoColumn.
```

## Audit weirdness (diperiksa & diperbaiki)

- [x] **AndroidManifest tanpa izin lokasi** → tambah `FINE/COARSE_LOCATION` + feature GPS.
- [x] **Rekaman mati saat layar mati** → foreground service `location` + notifikasi
      permanen + `WAKE_LOCK` + `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` +
      tombol **Buka Pengaturan** + panduan Xiaomi/Oppo/Vivo. Elapsed dihitung
      di service (akurat walau UI dibekukan).
- [x] **HP mati / service dibunuh = data hilang** → backup `track_backup_v1`
      tiap 15 dtk/50 titik + `restoreInterrupted()` (paused) + banner error
      tawarkan **Simpan Hasil** (titik dipertahankan, bukan dibuang).
- [x] **Abu-abu kosong di Beranda HP** → `Flexible` di dalam `Wrap` ilegal
      (layout gagal di release) → ganti `Row+Expanded`; tambah
      `AlwaysScrollableScrollPhysics` agar pull-refresh jalan saat list pendek.
- [x] **Share gagal / crash di HP** → `Directory.systemTemp` → 
      `path_provider.getTemporaryDirectory()` di dashboard/profile/track(GPX);
      picker **v13** (`pickFiles()->List<PlatformFile>`, kosong = Batal, bukan
      null) + filter ekstensi + try/catch + snackbar.
- [x] **Tile "API KEY REQUIRED" (CARTO kini berbayar)** → buang CARTO;
      primer `tile.openstreetmap.org` + fallback HOT (murni tanpa key, template
      persis Leaflet.js); gelap via `darkModeTileBuilder` bawaan flutter_map;
      atribusi `© OpenStreetMap contributors`.
- [x] **Metrik tak lengkap ("di mana tercepat?")** → tambah `movingTimeSec`,
      `fastestSplit`, `eleMinMax` (dites); Detail kini: Waktu gerak, Avg gerak,
      banner ⚡ Terkencang KM X + highlight split, Elev turun + min–maks;
      Rekam live: Max + Avg gerak + caption titik.
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
flutter test                   # 44 tes (21 lama + 14 GPS + 9 places/premium) harus hijau
flutter run                    # GPS: pakai HP fisik (USB debugging ON) — emulator: mock route
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
- Jarak GPS = Haversine per segmen tersaring; elevasi = gain/loss dengan step
  ≥2 m (noise barometer diabaikan); kecepatan avg = jarak/waktu elapsed,
  avg-gerak = jarak/waktu-bergerak (segmen ≥1 m/s); max = segmen tercepat
  ≤80 km/h (anti GPS-jump); split/tercepat otomatis per 1 km.
- Izin Android wajib: `FINE/COARSE`, `FOREGROUND_SERVICE(_LOCATION)`,
  `ACCESS_BACKGROUND_LOCATION`, `POST_NOTIFICATIONS`, `WAKE_LOCK`,
  `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`. iOS: Background Modes Location
  dicentang di Xcode (lihat TODO di `track_service.dart`).
- `file_picker` v13 breaking: `pickFiles()->List<PlatformFile>` (bukan
  `FilePickerResult?`); Batal = list kosong. Jangan pakai `.platform`.
