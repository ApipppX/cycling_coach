# CyclingCoach

Pelatih sepeda pribadi (Flutter, offline-first): catat latihan, analisis beban
berbasis sport-science, rekomendasi harian, planner event, statistik lengkap,
dan laporan PDF.

## Fitur

- **Beranda**: target mingguan, riwayat + cari/sort/hapus massal, impor & contoh CSV.
- **Coach AI**: rekomendasi hari ini (rest/easy/interval/tempo/long/taper),
  CTL/ATL/TSB, TRIMP, mix sesi, peringatan overreach & deload.
- **Statistik**: total keseluruhan (jarak, elevasi, jam, kkal, avg),
  grafik 8 minggu / 6 bulan / 3 tahun, tren per sesi, distribusi zona HR,
  rekor & streak mingguan.
- **Event**: target event + kesiapan %, plan latihan harian + progres,
  kalkulator ETA Anti-COT (tombol ? untuk panduan).
- **Profil**: nama/umur/berat/target, tema, backup & restore JSON, hapus data.
- **Detail sesi**: durasi, TRIMP, estimasi kalori, RPE, catatan + evaluasi sesi.
- Form latihan lengkap: tanggal, jarak, durasi/kecepatan (saling mengisi
  otomatis), elevasi, HR, catatan — dengan validasi.

## Data per sesi

Nama, tanggal, jarak, durasi, kecepatan, elevasi, HR rata-rata + zona,
catatan, TRIMP, estimasi kalori.

## Cara pakai Anti-COT (hari-H event)

1. Isi Target (km) + COT total (jam) + jam start. Buka dari tab Event agar
   target terisi otomatis.
2. Selama gowes isi minimal 2 dari 3: KM posisi, avg speed, waktu tempuh.
3. Tekan HITUNG → verdict AMAN/WASPADA/OVER COT, proyeksi jam finis, pace
   yang dibutuhkan di sisa jarak, dan tabel checkpoint per X km.
4. Update KM tiap pos + HITUNG lagi. Nyalakan Timer live agar waktu tempuh
   berjalan sendiri.

## Arsitektur

```
lib/src/
  models/     POJO CyclingActivity, EventGoal
  data/       Drift SQLite (migrasi v5) + SharedPreferences
  core/       coach_engine (TRIMP/CTL/ATL/TSB), health_stats,
              csv_utils, backup (JSON), report_pdf
  providers/  Riverpod StreamProvider
  ui/         app.dart + screens/ (per fitur) + widgets/
```

## Perintah

```powershell
flutter pub get
dart run build_runner build          # regenerasi Drift bila tabel berubah
flutter analyze
flutter test
flutter run -d emulator-5554
```

## Catatan build

- Gradle: tambah `--enable-native-access=ALL-UNNAMED` ke `org.gradle.jvmargs`
  dan `GRADLE_OPTS` untuk menekan warning JDK 27 (`native-platform`).
- Estimasi kalori & TRIMP tanpa HR bersifat perkiraan, bukan pengukuran lab.
