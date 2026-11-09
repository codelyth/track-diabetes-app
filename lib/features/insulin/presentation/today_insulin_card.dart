import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/insulin_repository.dart';
import '../domain/insulin_entry.dart';

class TodayInsulinCard extends StatefulWidget {
  const TodayInsulinCard({
    super.key,
    required this.userId,
    required this.onTap,
  });

  final String userId;
  final VoidCallback onTap;

  @override
  State<TodayInsulinCard> createState() => _TodayInsulinCardState();
}

class _TodayInsulinCardState extends State<TodayInsulinCard> {
  late final InsulinRepository _repository;
  late Stream<List<InsulinEntry>> _entriesStream;

  @override
  void initState() {
    super.initState();

    _repository = InsulinRepository(userId: widget.userId);
    _entriesStream = _repository.watchEntries();
  }

  String _two(int value) => value.toString().padLeft(2, '0');

  String _time(DateTime value) {
    final date = value.toLocal();

    return '${_two(date.hour)}:${_two(date.minute)}';
  }

  String _dose(double value) {
    final text = value == value.truncateToDouble()
        ? value.toStringAsFixed(0)
        : value.toString();

    return '${text.replaceAll('.', ',')} ünite';
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
          padding: const EdgeInsets.all(16),
          child: StreamBuilder<List<InsulinEntry>>(
            stream: _entriesStream,
            builder: (context, snapshot) {
              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);
              final tomorrow = DateTime(today.year, today.month, today.day + 1);

              final entries = (snapshot.data ?? <InsulinEntry>[])
                  .where((entry) {
                    final date = entry.administeredAt.toLocal();

                    return !date.isBefore(today) && date.isBefore(tomorrow);
                  })
                  .toList(growable: false);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.vaccines_outlined,
                        size: 20,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Bugünkü insülin',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                      if (snapshot.hasData && !snapshot.hasError)
                        Text(
                          '${entries.length} kayıt',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: AppColors.muted,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (snapshot.hasError)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('İnsülin kayıtları yüklenemedi.'),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _entriesStream = _repository.watchEntries();
                            });
                          },
                          child: const Text('Yeniden dene'),
                        ),
                      ],
                    )
                  else if (!snapshot.hasData)
                    const LinearProgressIndicator()
                  else if (entries.isEmpty)
                    const Text(
                      'Bugün kayıt yok. Bu, uygulama yapılmadığı '
                      'anlamına gelmez.',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    )
                  else ...[
                    ...entries.take(3).map((entry) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _time(entry.administeredAt),
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entry.insulinName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    entry.kind.label,
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                _dose(entry.doseUnits),
                                textAlign: TextAlign.end,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    if (entries.length > 3) ...[
                      const SizedBox(height: 6),
                      Text(
                        '+${entries.length - 3} kayıt daha',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
