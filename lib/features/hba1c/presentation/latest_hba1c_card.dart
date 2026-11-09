import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/hba1c_repository.dart';
import '../domain/hba1c_result.dart';

class LatestHba1cCard extends StatefulWidget {
  const LatestHba1cCard({
    super.key,
    required this.userId,
    required this.onTap,
    this.compact = false,
  });

  final String userId;
  final VoidCallback onTap;
  final bool compact;

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
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        child: Padding(
          padding: EdgeInsets.all(widget.compact ? 14 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.science_outlined,
                    size: 20,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 7),
                  const Expanded(
                    child: Text(
                      'Son HbA1c',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: AppColors.muted,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              StreamBuilder<List<Hba1cResult>>(
                stream: _resultsStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Yüklenemedi'),
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
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: LinearProgressIndicator(),
                    );
                  }

                  final results = snapshot.data!;
                  final latest = results.isEmpty ? null : results.first;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        latest == null
                            ? 'Sonuç yok'
                            : '%${latest.valuePercent.toString().replaceAll('.', ',')}',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        latest == null
                            ? 'Sonuç ekleyin'
                            : _date(latest.testDate),
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                      if (!widget.compact) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Kullanıcının kaydettiği laboratuvar sonucu.',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
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
