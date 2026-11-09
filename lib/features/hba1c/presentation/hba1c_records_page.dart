import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/hba1c_repository.dart';
import '../domain/hba1c_result.dart';
import 'add_hba1c_screen.dart';

enum _DetailAction { edit, delete }

class Hba1cRecordsPage extends StatefulWidget {
  const Hba1cRecordsPage({super.key, required this.userId});

  final String userId;

  @override
  State<Hba1cRecordsPage> createState() => _Hba1cRecordsPageState();
}

class _Hba1cRecordsPageState extends State<Hba1cRecordsPage> {
  late final Hba1cRepository _repository;
  late Stream<List<Hba1cResult>> _resultsStream;

  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();

    _repository = Hba1cRepository(userId: widget.userId);
    _resultsStream = _repository.watchResults();
  }

  String _two(int value) => value.toString().padLeft(2, '0');

  String _date(DateTime value) {
    final date = value.toLocal();

    return '${_two(date.day)}.${_two(date.month)}.${date.year}';
  }

  String _value(Hba1cResult result) {
    return '%${result.valuePercent.toString().replaceAll('.', ',')}';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showDetails(Hba1cResult result) async {
    if (_isDeleting) return;

    final action = await showModalBottomSheet<_DetailAction>(
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
                  'HbA1c: ${_value(result)}',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text('Tahlil tarihi: ${_date(result.testDate)}'),
                const SizedBox(height: 24),
                Text('Not', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  result.note.isEmpty ? 'Not eklenmemiş.' : result.note,
                  style: const TextStyle(height: 1.5),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop(_DetailAction.edit);
                  },
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Düzenle'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop(_DetailAction.delete);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Sonucu sil'),
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

    if (action == _DetailAction.edit) {
      await _edit(result);
    } else {
      await _delete(result);
    }
  }

  Future<void> _edit(Hba1cResult result) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            AddHba1cScreen(userId: widget.userId, initialResult: result),
      ),
    );

    if (!mounted || saved != true) return;

    _showMessage('HbA1c sonucu güncellendi.');
  }

  Future<void> _delete(Hba1cResult result) async {
    if (_isDeleting) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('HbA1c sonucunu sil?'),
          content: Text(
            '${_date(result.testDate)} tarihli '
            '${_value(result)} sonucu silinecek.\n\n'
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
      await _repository.deleteResult(result.id);

      if (!mounted) return;

      _showMessage('HbA1c sonucu silindi.');
    } on FirebaseException catch (error) {
      if (!mounted) return;

      _showMessage(
        error.code == 'permission-denied'
            ? 'Bu sonucu silmek için erişim izni alınamadı.'
            : 'Sonuç silinemedi. Bağlantınızı kontrol edip tekrar deneyin.',
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
          child: StreamBuilder<List<Hba1cResult>>(
            stream: _resultsStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'HbA1c kayıtları yüklenemedi.',
                          textAlign: TextAlign.center,
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _resultsStream = _repository.watchResults();
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

              final results = snapshot.data!;

              if (results.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Henüz HbA1c sonucu yok.\n'
                      'Ekleme düğmesinden ilk laboratuvar '
                      'sonucunuzu kaydedebilirsiniz.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.muted, height: 1.6),
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                itemCount: results.length,
                separatorBuilder: (context, index) {
                  return const SizedBox(height: 12);
                },
                itemBuilder: (context, index) {
                  final result = results[index];

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
                          Icons.science_outlined,
                          color: AppColors.primary,
                        ),
                      ),
                      title: Text(
                        _value(result),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text('Tahlil: ${_date(result.testDate)}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showDetails(result),
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
