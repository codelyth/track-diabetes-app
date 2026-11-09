import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/insulin_repository.dart';
import '../domain/insulin_entry.dart';
import 'add_insulin_screen.dart';

enum _InsulinAction { edit, delete }

class InsulinRecordsPage extends StatefulWidget {
  const InsulinRecordsPage({super.key, required this.userId});

  final String userId;

  @override
  State<InsulinRecordsPage> createState() => _InsulinRecordsPageState();
}

class _InsulinRecordsPageState extends State<InsulinRecordsPage> {
  late final InsulinRepository _repository;
  late Stream<List<InsulinEntry>> _entriesStream;

  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();

    _repository = InsulinRepository(userId: widget.userId);
    _entriesStream = _repository.watchEntries();
  }

  String _two(int value) => value.toString().padLeft(2, '0');

  String _dateTime(DateTime value) {
    final date = value.toLocal();

    return '${_two(date.day)}.${_two(date.month)}.${date.year}'
        ' • ${_two(date.hour)}:${_two(date.minute)}';
  }

  String _dose(double value) {
    final text = value == value.truncateToDouble()
        ? value.toStringAsFixed(0)
        : value.toString();

    return '${text.replaceAll('.', ',')} ünite';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showDetails(InsulinEntry entry) async {
    if (_isDeleting) return;

    final action = await showModalBottomSheet<_InsulinAction>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  entry.insulinName,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text('${entry.kind.label} • ${_dose(entry.doseUnits)}'),
                const SizedBox(height: 12),
                Text('Uygulama: ${_dateTime(entry.administeredAt)}'),
                const SizedBox(height: 24),
                Text('Not', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  entry.note.isEmpty ? 'Not eklenmemiş.' : entry.note,
                  style: const TextStyle(height: 1.5),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop(_InsulinAction.edit);
                  },
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Düzenle'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop(_InsulinAction.delete);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Kaydı sil'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Kapat'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || action == null) return;

    if (action == _InsulinAction.edit) {
      await _edit(entry);
    } else {
      await _delete(entry);
    }
  }

  Future<void> _edit(InsulinEntry entry) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            AddInsulinScreen(userId: widget.userId, initialEntry: entry),
      ),
    );

    if (!mounted || saved != true) return;

    _showMessage('İnsülin kaydı güncellendi.');
  }

  Future<void> _delete(InsulinEntry entry) async {
    if (_isDeleting) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('İnsülin kaydını sil?'),
          content: Text(
            '${entry.insulinName} • ${_dose(entry.doseUnits)}\n'
            '${_dateTime(entry.administeredAt)}\n\n'
            'Bu uygulama kaydı kalıcı olarak silinecek. '
            'Bu işlem geri alınamaz.',
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

    setState(() => _isDeleting = true);

    try {
      await _repository.deleteEntry(entry.id);

      if (!mounted) return;

      _showMessage('İnsülin kaydı silindi.');
    } on FirebaseException catch (error) {
      if (!mounted) return;

      _showMessage(
        error.code == 'permission-denied'
            ? 'Bu kaydı silmek için erişim izni alınamadı.'
            : 'Kayıt silinemedi. Bağlantınızı kontrol edip tekrar deneyin.',
      );
    } catch (_) {
      if (!mounted) return;

      _showMessage('İşlem tamamlanamadı. Lütfen tekrar deneyin.');
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_isDeleting) ...[
          const LinearProgressIndicator(),
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Silme işlemi için sunucu onayı bekleniyor. '
              'Çevrimdışıysanız bağlantı geldiğinde işlem devam eder.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted),
            ),
          ),
        ],
        Expanded(
          child: StreamBuilder<List<InsulinEntry>>(
            stream: _entriesStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'İnsülin kayıtları yüklenemedi.',
                          textAlign: TextAlign.center,
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _entriesStream = _repository.watchEntries();
                            });
                          },
                          child: const Text('Yeniden dene'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final entries = snapshot.data!;

              if (entries.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Henüz insülin uygulama kaydı yok.\n'
                      'Bu, enjeksiyon yapılmadığı anlamına gelmez.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.muted, height: 1.6),
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                itemCount: entries.length,
                separatorBuilder: (context, index) {
                  return const SizedBox(height: 12);
                },
                itemBuilder: (context, index) {
                  final entry = entries[index];

                  return Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      enabled: !_isDeleting,
                      contentPadding: const EdgeInsets.all(16),
                      leading: const CircleAvatar(
                        backgroundColor: AppColors.lavender,
                        child: Icon(
                          Icons.vaccines_outlined,
                          color: AppColors.primary,
                        ),
                      ),
                      title: Text(
                        entry.insulinName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '${entry.kind.label} • ${_dose(entry.doseUnits)}\n'
                        '${_dateTime(entry.administeredAt)}',
                      ),
                      isThreeLine: true,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showDetails(entry),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
