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
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.vaccines_outlined, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Bugünkü insülin kayıtları',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.muted),
                ],
              ),
              const SizedBox(height: 16),
              StreamBuilder<List<InsulinEntry>>(
                stream: _entriesStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Column(
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
                    );
                  }

                  if (!snapshot.hasData) {
                    return const LinearProgressIndicator();
                  }

                  final now = DateTime.now();
                  final today = DateTime(now.year, now.month, now.day);
                  final tomorrow = DateTime(
                    today.year,
                    today.month,
                    today.day + 1,
                  );

                  final entries = snapshot.data!
                      .where((entry) {
                        final date = entry.administeredAt.toLocal();

                        return !date.isBefore(today) && date.isBefore(tomorrow);
                      })
                      .toList(growable: false);

                  if (entries.isEmpty) {
                    return const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bugün için kayıt yok',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Kayıt bulunmaması, enjeksiyon '
                          'yapılmadığı anlamına gelmez.',
                          style: TextStyle(color: AppColors.muted, height: 1.5),
                        ),
                      ],
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '${entries.length} uygulama kaydı',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...entries.take(3).map((entry) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
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
                                    const SizedBox(height: 4),
                                    Text(
                                      '${entry.kind.label} • '
                                      '${_dose(entry.doseUnits)}',
                                      style: const TextStyle(
                                        color: AppColors.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      if (entries.length > 3) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Diğer ${entries.length - 3} kayıt için dokunun.',
                          style: const TextStyle(color: AppColors.primary),
                        ),
                      ],
                      const SizedBox(height: 8),
                      const Text(
                        'Kullanıcının kaydettiği uygulamalar.',
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
