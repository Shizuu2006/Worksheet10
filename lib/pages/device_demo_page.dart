import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../cloud_config.dart';
import '../services/device_location_service.dart';
import '../services/draft_repository.dart';
import '../services/photo_upload_service.dart';
import 'sensor_demo_page.dart';

class DeviceDemoPage extends StatefulWidget {
  const DeviceDemoPage({super.key});

  @override
  State<DeviceDemoPage> createState() => _DeviceDemoPageState();
}

class _DeviceDemoPageState extends State<DeviceDemoPage> {
  final _nameController = TextEditingController();
  final _picker = ImagePicker();
  final _drafts = DraftRepository();
  final _location = DeviceLocationService();
  final _uploader = PhotoUploadService();

  String? _photoPath;
  String? _storagePath;
  String? _publicUrl;
  double? _latitude;
  double? _longitude;
  LocationFailureType? _locationError;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _restoreLocalDraft();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _notice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _restoreLocalDraft() async {
    try {
      final draft = await _drafts.load();
      if (!mounted) return;
      final savedPhotoPath = draft['photoPath'] as String?;
      final photoStillExists =
          savedPhotoPath != null && File(savedPhotoPath).existsSync();
      setState(() {
        _nameController.text = draft['name'] as String? ?? '';
        _photoPath = photoStillExists ? savedPhotoPath : null;
        _storagePath = draft['storagePath'] as String?;
        _publicUrl = draft['publicUrl'] as String?;
        final lat = draft['latitude'];
        final lng = draft['longitude'];
        _latitude = lat is num ? lat.toDouble() : null;
        _longitude = lng is num ? lng.toDouble() : null;
      });
      await _recoverInterruptedPicker();
    } catch (error) {
      _notice('Draft lokal belum dapat dibaca: $error');
    }
  }

  Future<void> _recoverInterruptedPicker() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    final lost = await _picker.retrieveLostData();
    if (lost.isEmpty) return;
    if (lost.files != null && lost.files!.isNotEmpty) {
      await _acceptPhoto(lost.files!.first);
      _notice('Foto dari proses kamera/galeri yang terputus dipulihkan.');
    } else if (lost.exception != null) {
      _notice('Pemulihan foto gagal: ${lost.exception}');
    }
  }

  Future<void> _saveDraft({bool showMessage = true}) async {
    await _drafts.save({
      'name': _nameController.text.trim(),
      'photoPath': _photoPath,
      'latitude': _latitude,
      'longitude': _longitude,
      'storagePath': _storagePath,
      'publicUrl': _publicUrl,
    });
    if (showMessage) _notice('Draft berhasil disimpan di perangkat.');
  }

  Future<void> _acceptPhoto(XFile picked) async {
    final permanentPath = await _drafts.savePermanentPhoto(picked);
    if (!mounted) return;
    setState(() {
      _photoPath = permanentPath;
      _storagePath = null;
      _publicUrl = null;
    });
    await _saveDraft(showMessage: false);
  }

  Future<void> _choosePhoto(ImageSource source) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 80,
      );
      if (picked == null) {
        _notice('Pemilihan foto dibatalkan; draft tidak berubah.');
        return;
      }
      await _acceptPhoto(picked);
      _notice('Foto disalin ke penyimpanan permanen aplikasi.');
    } on PlatformException catch (error) {
      _notice(
        'Kamera/galeri tidak tersedia (${error.code}). Cek izin perangkat.',
      );
    } on FormatException catch (error) {
      _notice(error.message);
    } catch (error) {
      _notice('Gagal memilih foto: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _getLocation() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _locationError = null;
    });
    try {
      final position = await _location.getPosition();
      if (!mounted) return;
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
      await _saveDraft(showMessage: false);
      _notice('Koordinat berhasil diambil dan tersimpan dalam draft.');
    } on LocationFailure catch (error) {
      if (!mounted) return;
      setState(() => _locationError = error.type);
      _notice(error.message);
    } on TimeoutException {
      _notice('Waktu mencari GPS habis. Coba dekat jendela/area terbuka.');
    } catch (error) {
      _notice('Lokasi tidak dapat diambil: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _upload() async {
    if (_busy || !CloudConfig.enabled) return;
    if (_nameController.text.trim().isEmpty) {
      _notice('Isi nama kos sebelum mengunggah foto.');
      return;
    }
    final path = _photoPath;
    if (path == null || !File(path).existsSync()) {
      _notice('Ambil/pilih foto terlebih dahulu.');
      return;
    }

    setState(() => _busy = true);
    try {
      final result = await _uploader.upload(File(path));
      if (!mounted) return;
      setState(() {
        _storagePath = result.storagePath;
        _publicUrl = result.publicUrl;
      });
      await _saveDraft(showMessage: false);
      _notice('Berhasil! Foto tersedia pada Supabase Storage.');
    } on AuthException catch (error) {
      _notice('Login anonymous Supabase gagal: ${error.message}');
    } on StorageException catch (error) {
      _notice('Upload ditolak Storage: ${error.message}');
    } catch (error) {
      _notice('Gagal upload: $error. Draft lokal tetap ada.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final photoExists = _photoPath != null && File(_photoPath!).existsSync();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.home_work_outlined,
                color: colors.onPrimaryContainer,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'KosFinder',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'DEVICE DEMO',
                  style: theme.textTheme.labelSmall?.copyWith(
                    letterSpacing: 1.2,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Demo sensor',
            icon: const Icon(Icons.sensors),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SensorDemoPage())),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth >= 760
              ? 680.0
              : constraints.maxWidth;

          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: maxWidth,
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  _buildHero(context),
                  const SizedBox(height: 24),
                  _sectionTitle(
                    context,
                    title: 'Informasi kos',
                    subtitle: 'Mulai dengan nama tempat yang mudah dikenali.',
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Nama kos',
                      hintText: 'Contoh: Kos Melati',
                      prefixIcon: Icon(Icons.apartment_outlined),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _sectionTitle(
                    context,
                    title: 'Foto properti',
                    subtitle: 'Gunakan JPG atau PNG, maksimal 5 MB.',
                  ),
                  const SizedBox(height: 12),
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (photoExists)
                          Semantics(
                            label: 'Foto kos yang dipilih',
                            child: Image.file(
                              File(_photoPath!),
                              height: 210,
                              fit: BoxFit.cover,
                            ),
                          )
                        else
                          Container(
                            height: 168,
                            color: colors.secondaryContainer,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_photo_alternate_outlined,
                                  size: 42,
                                  color: colors.onSecondaryContainer,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Tambahkan foto kamar kos',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    color: colors.onSecondaryContainer,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _busy
                                      ? null
                                      : () => _choosePhoto(ImageSource.camera),
                                  icon: const Icon(Icons.camera_alt_outlined),
                                  label: const Text('Kamera'),
                                  style: _actionButtonStyle(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _busy
                                      ? null
                                      : () => _choosePhoto(ImageSource.gallery),
                                  icon: const Icon(
                                    Icons.photo_library_outlined,
                                  ),
                                  label: const Text('Galeri'),
                                  style: _actionButtonStyle(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _sectionTitle(
                    context,
                    title: 'Lokasi kos',
                    subtitle:
                        'Koordinat ponsel dapat ditambahkan secara opsional.',
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                color: colors.primary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _latitude == null || _longitude == null
                                          ? 'Koordinat belum ditambahkan'
                                          : 'Koordinat tersimpan',
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    SelectableText(
                                      _latitude == null || _longitude == null
                                          ? 'Anda tetap dapat menyimpan draft tanpa lokasi.'
                                          : 'Lat ${_latitude!.toStringAsFixed(6)}  ·  '
                                                'Lng ${_longitude!.toStringAsFixed(6)}',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: colors.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.tonalIcon(
                              onPressed: _busy ? null : _getLocation,
                              icon: const Icon(Icons.my_location),
                              label: const Text('Ambil Koordinat GPS'),
                              style: _actionButtonStyle(),
                            ),
                          ),
                          if (_locationError ==
                                  LocationFailureType.serviceDisabled ||
                              _locationError ==
                                  LocationFailureType.deniedForever) ...[
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed:
                                    _locationError ==
                                        LocationFailureType.serviceDisabled
                                    ? () => Geolocator.openLocationSettings()
                                    : () => Geolocator.openAppSettings(),
                                icon: const Icon(Icons.settings_outlined),
                                label: Text(
                                  _locationError ==
                                          LocationFailureType.serviceDisabled
                                      ? 'Buka pengaturan lokasi'
                                      : 'Buka pengaturan izin aplikasi',
                                ),
                                style: _actionButtonStyle(),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _sectionTitle(
                    context,
                    title: 'Simpan informasi',
                    subtitle: 'Draft disimpan pada perangkat ini.',
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _busy
                          ? null
                          : () async {
                              try {
                                await _saveDraft();
                              } catch (error) {
                                _notice('Gagal menyimpan draft: $error');
                              }
                            },
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Simpan Draft Lokal'),
                      style: _actionButtonStyle(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _busy || !CloudConfig.enabled ? null : _upload,
                      icon: const Icon(Icons.cloud_upload_outlined),
                      label: const Text('Upload Foto ke Supabase (opsional)'),
                      style: _actionButtonStyle(),
                    ),
                  ),
                  if (!CloudConfig.enabled) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Upload belum diaktifkan. Draft lokal tetap tersedia.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (_busy) ...[
                    const SizedBox(height: 16),
                    const LinearProgressIndicator(),
                  ],
                  if (_storagePath != null || _publicUrl != null) ...[
                    const SizedBox(height: 16),
                    Card(
                      color: colors.primaryContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Foto berhasil diunggah',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: colors.onPrimaryContainer,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (_storagePath != null) ...[
                              const SizedBox(height: 10),
                              Text(
                                'Lokasi objek Storage',
                                style: theme.textTheme.labelMedium,
                              ),
                              SelectableText(_storagePath!),
                            ],
                            if (_publicUrl != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                'URL foto publik',
                                style: theme.textTheme.labelMedium,
                              ),
                              SelectableText(_publicUrl!),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    'GPS menunjukkan posisi ponsel, bukan otomatis posisi kos. '
                    'Gunakan foto demo tanpa data pribadi.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final statusLabel = CloudConfig.enabled ? 'Lokal + Supabase' : 'Mode lokal';
    final statusIcon = CloudConfig.enabled
        ? Icons.cloud_done_outlined
        : Icons.offline_bolt;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.primary, colors.primary.withValues(alpha: 0.84)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -34,
            top: -48,
            child: Container(
              width: 156,
              height: 156,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, color: Colors.white, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        statusLabel,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(
    BuildContext context, {
    required String title,
    required String subtitle,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  ButtonStyle _actionButtonStyle() => ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(Size.fromHeight(52)),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
