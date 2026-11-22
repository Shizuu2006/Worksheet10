# KosFinder Device Demo

Aplikasi Flutter standalone untuk praktik kamera/galeri, GPS, penyimpanan
draft lokal, Supabase Storage, dan sensor accelerometer.

## Menjalankan aplikasi lokal

```bash
flutter pub get
flutter run
```

## Menjalankan aplikasi dengan Supabase

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://PROJECT_ID.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

Gunakan publishable key, bukan service_role atau secret key.

## Pengujian

```bash
flutter analyze
flutter test
```

## Checklist Praktik 7

| No. | Kasus uji | Hasil yang diharapkan | Status |
| --- | --- | --- | --- |
| 1 | Foto melalui kamera | Pratinjau tampil dan tersalin ke documents | Belum diuji fisik |
| 2 | Foto melalui galeri | Pratinjau tampil | Belum diuji fisik |
| 3 | Batalkan galeri | Aplikasi stabil dan foto lama tetap | Belum diuji fisik |
| 4 | Kamera/galeri ditolak | Pesan izin tampil dan aplikasi tetap berjalan | Belum diuji fisik |
| 5 | GPS diberikan | Latitude dan longitude tampil | Belum diuji fisik |
| 6 | GPS ditolak | Pesan kesalahan tampil dan draft tetap bisa disimpan | Belum diuji fisik |
| 7 | GPS nonaktif | Tampil tombol pengaturan lokasi | Belum diuji fisik |
| 8 | Tutup dan buka aplikasi | Nama, foto, dan lokasi dipulihkan | Belum diuji fisik |
| 9 | Tanpa internet | Draft lokal tetap berfungsi | Belum diuji fisik |
| 10 | Upload Supabase berhasil | File muncul pada bucket dan folder UID | Belum diuji fisik |
| 11 | Upload saat offline | Pesan gagal tampil dan draft lokal tetap ada | Belum diuji fisik |
| 12 | Sensor digerakkan | Nilai X, Y, dan Z berubah | Belum diuji fisik |

## N. Troubleshooting

| Masalah | Pemeriksaan / tindakan |
| --- | --- |
| Compile error saat `pub add` | Periksa minimum Flutter SDK, Java, dan Gradle yang dibutuhkan versi plugin pada pub.dev. |
| Project tetap meminta login | Pastikan `main.dart` menggunakan versi standalone, bukan source dari Worksheet 9. |
| Kamera tidak bekerja | Gunakan perangkat fisik; periksa permission dan konfigurasi `Info.plist`. |
| Foto HEIC gagal | Gunakan JPG/PNG; konversi format dapat ditambahkan sebagai pengayaan. |
| Data foto hilang | Pastikan foto disalin ke Application Documents Directory. |
| Lokasi tidak keluar | Periksa GPS aktif, permission, lokasi simulasi, dan timeout. |
| Aplikasi meminta credential | Mode lokal tidak memerlukannya. Jalankan `flutter run` tanpa `--dart-define`. |
| Upload dinonaktifkan | Tambahkan URL dan publishable key melalui `--dart-define`. |
| Error 403 saat upload | Periksa Anonymous Sign-Ins, bucket, objectPath UUID, dan policy RLS INSERT. |
| Upload gambar format salah | Atur bucket dengan batas maksimal 5 MB dan MIME `image/jpeg` serta `image/png`. |
| Sensor tidak tersedia | Uji di HP fisik dan periksa persyaratan `sensors_plus` serta `NSMotionUsageDescription` pada iOS. |
