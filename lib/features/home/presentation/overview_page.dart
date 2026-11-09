import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../glucose/data/glucose_repository.dart';
import '../../glucose/domain/glucose_reading.dart';
import '../../hba1c/presentation/latest_hba1c_card.dart';
import '../../insulin/presentation/today_insulin_card.dart';

enum _SummaryPeriod {
  daily('Günlük', 1),
  weekly('Haftalık', 7),
  monthly('Aylık', 30);

  const _SummaryPeriod(this.label, this.days);

  final String label;
  final int days;
}

class OverviewPage extends StatefulWidget {
  const OverviewPage({
    super.key,
    required this.userId,
    required this.onOpenRecords,
    required this.onOpenReminders,
    required this.onOpenHba1c,
    required this.onOpenInsulin,
  });

  final String userId;
  final VoidCallback onOpenRecords;
  final VoidCallback onOpenReminders;
  final VoidCallback onOpenHba1c;
  final VoidCallback onOpenInsulin;

  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> {
  late final GlucoseRepository _repository;
  late Stream<List<GlucoseReading>> _readingsStream;

  _SummaryPeriod _period = _SummaryPeriod.daily;

  @override
  void initState() {
    super.initState();

    _repository = GlucoseRepository(userId: widget.userId);
    _readingsStream = _repository.watchReadings();
  }

  String _two(int value) => value.toString().padLeft(2, '0');

  String _date(DateTime date) {
    return '${_two(date.day)}.${_two(date.month)}.${date.year}';
  }

  String _time(DateTime date) {
    return '${_two(date.hour)}:${_two(date.minute)}';
  }

  String _average(List<GlucoseReading> readings) {
    if (readings.isEmpty) return 'Kayıt yok';

    final total = readings.fold<int>(
      0,
      (sum, reading) => sum + reading.valueMgDl,
    );

    final average = total / readings.length;
    final formatted = average.toStringAsFixed(1).replaceAll('.', ',');

    return '$formatted mg/dL';
  }

  void _retry() {
    setState(() {
      _readingsStream = _repository.watchReadings();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Günlük takibiniz',
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(color: AppColors.text, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text(
          'Detayları görmek için ilgili karta dokunun.',
          style: TextStyle(color: AppColors.muted, height: 1.5),
        ),
        const SizedBox(height: 24),
        StreamBuilder<List<GlucoseReading>>(
          stream: _readingsStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Şeker ölçümleri yüklenemedi. '
                    'Bağlantınızı ve erişim izinlerinizi kontrol edin.',
                    textAlign: TextAlign.center,
                  ),
                  TextButton.icon(
                    onPressed: _retry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Yeniden dene'),
                  ),
                ],
              );
            }

            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final readings = snapshot.data!;
            final latest = readings.isEmpty ? null : readings.first;
            final latestDate = latest?.measuredAt.toLocal();

            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);

            final start = DateTime(
              today.year,
              today.month,
              today.day - _period.days + 1,
            );

            final endExclusive = DateTime(
              today.year,
              today.month,
              today.day + 1,
            );

            final selectedReadings = readings
                .where((reading) {
                  final date = reading.measuredAt.toLocal();

                  return !date.isBefore(start) && date.isBefore(endExclusive);
                })
                .toList(growable: false);

            final fastingReadings = selectedReadings
                .where((reading) => reading.type == GlucoseType.fasting)
                .toList(growable: false);

            final postMealReadings = selectedReadings
                .where((reading) => reading.type == GlucoseType.postMeal)
                .toList(growable: false);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _OverviewCard(
                  onTap: widget.onOpenRecords,
                  icon: Icons.water_drop_outlined,
                  title: 'Son şeker ölçümü',
                  value: latest == null
                      ? 'Henüz ölçüm yok'
                      : '${latest.valueMgDl} mg/dL',
                  description: latest == null || latestDate == null
                      ? 'İlk ölçümünüzü Kayıtlar bölümünden ekleyebilirsiniz.'
                      : '${latest.type.label} • '
                            '${_date(latestDate)} • ${_time(latestDate)}',
                  highlighted: true,
                ),
                const SizedBox(height: 24),
                Text(
                  'Ölçüm ortalamaları',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                SegmentedButton<_SummaryPeriod>(
                  segments: _SummaryPeriod.values.map((period) {
                    return ButtonSegment<_SummaryPeriod>(
                      value: period,
                      label: Text(period.label),
                    );
                  }).toList(),
                  selected: {_period},
                  onSelectionChanged: (selection) {
                    setState(() => _period = selection.first);
                  },
                ),
                const SizedBox(height: 12),
                Text(
                  '${_date(start)} – ${_date(today)}',
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 16),
                _OverviewCard(
                  onTap: widget.onOpenRecords,
                  icon: Icons.water_drop_outlined,
                  title: 'Açlık ortalaması',
                  value: _average(fastingReadings),
                  description: '${fastingReadings.length} ölçüm üzerinden',
                ),
                const SizedBox(height: 16),
                _OverviewCard(
                  onTap: widget.onOpenRecords,
                  icon: Icons.restaurant_outlined,
                  title: 'Tokluk ortalaması',
                  value: _average(postMealReadings),
                  description: '${postMealReadings.length} ölçüm üzerinden',
                ),
                const SizedBox(height: 16),
                _OverviewCard(
                  onTap: widget.onOpenRecords,
                  icon: Icons.query_stats,
                  title: 'Genel ortalama',
                  value: _average(selectedReadings),
                  description:
                      '${selectedReadings.length} ölçüm • '
                      'Açlık ve tokluk birlikte',
                ),
                const SizedBox(height: 12),
                const Text(
                  'Ortalamalar yalnızca kaydettiğiniz '
                  'ölçümlerden hesaplanır.',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        LatestHba1cCard(
          key: ValueKey('latest-hba1c-${widget.userId}'),
          userId: widget.userId,
          onTap: widget.onOpenHba1c,
        ),
        const SizedBox(height: 16),
        _OverviewCard(
          onTap: widget.onOpenReminders,
          icon: Icons.alarm_outlined,
          title: 'Sıradaki hatırlatıcı',
          value: 'Hatırlatıcılar hazırlanıyor',
          description: 'Hatırlatıcılar bölümünü açmak için dokunun.',
        ),
        const SizedBox(height: 16),
        TodayInsulinCard(
          key: ValueKey('today-insulin-${widget.userId}'),
          userId: widget.userId,
          onTap: widget.onOpenInsulin,
        ),
      ],
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.description,
    this.onTap,
    this.highlighted = false,
  });

  final IconData icon;
  final String title;
  final String value;
  final String description;
  final VoidCallback? onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: highlighted ? AppColors.lavender : Colors.white,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (onTap != null)
                    const Icon(Icons.chevron_right, color: AppColors.muted),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                value,
                style: TextStyle(
                  fontSize: highlighted ? 28 : 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: const TextStyle(color: AppColors.muted, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
