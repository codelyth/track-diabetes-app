import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/hba1c_repository.dart';
import '../domain/hba1c_result.dart';

class Hba1cRecordsPage extends StatefulWidget {
  const Hba1cRecordsPage({super.key, required this.userId});

  final String userId;

  @override
  State<Hba1cRecordsPage> createState() => _Hba1cRecordsPageState();
}

class _Hba1cRecordsPageState extends State<Hba1cRecordsPage> {
  late final Hba1cRepository _repository;
  late Stream<List<Hba1cResult>> _resultsStream;

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

  void _showDetails(Hba1cResult result) {
    showModalBottomSheet<void>(
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
                  'HbA1c: %${result.valuePercent.toString().replaceAll('.', ',')}',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text('Tahlil tarihi: ${_date(result.testDate)}'),
                const SizedBox(height: 24),
                Text('Not', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(result.note.isEmpty ? 'Not eklenmemiş.' : result.note),
                const SizedBox(height: 24),
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
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Hba1cResult>>(
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
                'Ekleme düğmesinden ilk laboratuvar sonucunuzu kaydedebilirsiniz.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted, height: 1.6),
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          itemCount: results.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final result = results[index];

            return Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: const CircleAvatar(
                  backgroundColor: AppColors.lavender,
                  child: Icon(Icons.science_outlined, color: AppColors.primary),
                ),
                title: Text(
                  '%${result.valuePercent.toString().replaceAll('.', ',')}',
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
    );
  }
}
