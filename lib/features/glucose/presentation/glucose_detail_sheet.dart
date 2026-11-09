import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/glucose_repository.dart';
import '../domain/glucose_reading.dart';
import 'add_glucose_screen.dart';

class GlucoseDetailSheet extends StatefulWidget {
  const GlucoseDetailSheet({
    super.key,
    required this.reading,
    required this.repository,
  });

  final GlucoseReading reading;
  final GlucoseRepository repository;

  @override
  State<GlucoseDetailSheet> createState() => _GlucoseDetailSheetState();
}

class _GlucoseDetailSheetState extends State<GlucoseDetailSheet> {
  bool _isDeleting = false;
  bool _isEditing = false;
  String? _error;

  bool get _isBusy => _isDeleting || _isEditing;

  String _two(int value) => value.toString().padLeft(2, '0');

  Future<void> _edit() async {
    if (_isBusy) return;

    setState(() {
      _isEditing = true;
      _error = null;
    });

    try {
      final saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => AddGlucoseScreen(
            userId: widget.repository.userId,
            initialReading: widget.reading,
          ),
        ),
      );

      if (!mounted || saved != true) return;

      final messenger = ScaffoldMessenger.of(context);

      // Eski bilgileri gösteren detay penceresini kapatır.
      // false: Kayıtlar sayfasındaki "silindi" mesajını tetiklemez.
      Navigator.of(context).pop(false);

      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Ölçüm güncellendi.')));
    } finally {
      if (mounted) {
        setState(() => _isEditing = false);
      }
    }
  }

  Future<void> _delete() async {
    if (_isBusy) return;

    final reading = widget.reading;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Ölçümü sil?'),
          content: Text(
            '${reading.valueMgDl} mg/dL değerindeki '
            '${reading.type.label.toLowerCase()} ölçümü silinecek.\n\n'
            'Bu işlem geri alınamaz. Ölçüm ortalamalarınız '
            'kalan kayıtlara göre güncellenecek.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Vazgeç'),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Sil'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isDeleting = true;
      _error = null;
    });

    try {
      await widget.repository.deleteReading(reading.id);

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } on FirebaseException catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.code == 'permission-denied'
            ? 'Bu kaydı silmek için erişim izni alınamadı.'
            : 'Ölçüm silinemedi. Bağlantınızı kontrol edip tekrar deneyin.';
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = 'İşlem tamamlanamadı. Lütfen tekrar deneyin.';
      });
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final reading = widget.reading;
    final date = reading.measuredAt.toLocal();

    final dateLabel = '${_two(date.day)}.${_two(date.month)}.${date.year}';

    final timeLabel = '${_two(date.hour)}:${_two(date.minute)}';

    return PopScope<bool>(
      canPop: !_isBusy,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Ölçüm detayı',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 20),
              Text(
                '${reading.valueMgDl} mg/dL',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text('${reading.type.label} • $dateLabel • $timeLabel'),
              const SizedBox(height: 24),
              Text('Not', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                reading.note.isEmpty ? 'Not eklenmemiş.' : reading.note,
                style: const TextStyle(height: 1.5),
              ),
              const SizedBox(height: 28),
              if (_error != null) ...[
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 16),
              ],
              FilledButton.icon(
                onPressed: _isBusy ? null : _edit,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Düzenle'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _isBusy ? null : _delete,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                icon: const Icon(Icons.delete_outline),
                label: Text(_isDeleting ? 'Siliniyor...' : 'Kaydı sil'),
              ),
              if (_isDeleting) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
                const SizedBox(height: 12),
                const Text(
                  'Sunucu onayı bekleniyor. Çevrimdışıysanız '
                  'bağlantı geldiğinde işlem devam eder.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted),
                ),
              ],
              const SizedBox(height: 8),
              TextButton(
                onPressed: _isBusy
                    ? null
                    : () => Navigator.of(context).pop(false),
                child: const Text('Kapat'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
