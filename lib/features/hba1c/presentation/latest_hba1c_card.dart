import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/hba1c_repository.dart';
import '../domain/hba1c_result.dart';

class LatestHba1cCard extends StatefulWidget {
  const LatestHba1cCard({super.key, required this.userId, required this.onTap});

  final String userId;
  final VoidCallback onTap;

  @override
  State<LatestHba1cCard> createState() => _LatestHba1cCardState();
}

class _LatestHba1cCardState extends State<LatestHba1cCard> {
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

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.science_outlined, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Son HbA1c sonucu',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.muted),
                ],
              ),
              const SizedBox(height: 16),
              StreamBuilder<List<Hba1cResult>>(
                stream: _resultsStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('HbA1c sonucu yüklenemedi.'),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _resultsStream = _repository.watchResults();
                            });
                          },
                          child: const Text('Yeniden dene'),
                        ),
                      ],
                    );
                  }

                  if (!snapshot.hasData) {
                    return const LinearProgressIndicator();
                  }

                  final results = snapshot.data!;

                  if (results.isEmpty) {
                    return const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Henüz sonuç yok',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Laboratuvar sonucunuzu Kayıtlar bölümünden ekleyin.',
                          style: TextStyle(color: AppColors.muted, height: 1.5),
                        ),
                      ],
                    );
                  }

                  final latest = results.first;
                  final value = latest.valuePercent.toString().replaceAll(
                    '.',
                    ',',
                  );

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '%$value',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tahlil tarihi: ${_date(latest.testDate)}',
                        style: const TextStyle(color: AppColors.muted),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Kullanıcının kaydettiği laboratuvar sonucu.',
                        style: TextStyle(color: AppColors.muted, fontSize: 12),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
