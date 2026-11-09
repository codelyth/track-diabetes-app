import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../glucose/data/glucose_repository.dart';
import '../../glucose/domain/glucose_reading.dart';
import '../../glucose/presentation/glucose_summary_chart.dart';
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

class _OverviewPageState extends State<OverviewPage>
    with WidgetsBindingObserver {
  late final GlucoseRepository _repository;
  late Stream<List<GlucoseReading>> _readingsStream;

  Timer? _refreshTimer;
  _SummaryPeriod _period = _SummaryPeriod.daily;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _repository = GlucoseRepository(userId: widget.userId);
    _readingsStream = _repository.watchReadings();

    // Tarih değiştiğinde günlük özetin eski günde kalmasını önler.
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() {});
    }
  }

  String _two(int value) => value.toString().padLeft(2, '0');

  String _date(DateTime value) {
    return '${_two(value.day)}.${_two(value.month)}.${value.year}';
  }

  String _time(DateTime value) {
    return '${_two(value.hour)}:${_two(value.minute)}';
  }

  String _average(List<GlucoseReading> readings) {
    if (readings.isEmpty) return '—';

    final total = readings.fold<double>(
      0,
      (sum, reading) => sum + reading.valueMgDl,
    );

    return (total / readings.length).toStringAsFixed(1).replaceAll('.', ',');
  }

  Widget _buildGlucoseSection() {
    return StreamBuilder<List<GlucoseReading>>(
      stream: _readingsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _DashboardCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Şeker ölçümleri yüklenemedi.'),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _readingsStream = _repository.watchReadings();
                    });
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Yeniden dene'),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData) {
          return const _DashboardCard(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
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

        final endExclusive = DateTime(today.year, today.month, today.day + 1);

        final selected = readings
            .where((reading) {
              final date = reading.measuredAt.toLocal();

              return !date.isBefore(start) && date.isBefore(endExclusive);
            })
            .toList(growable: false);

        final fasting = selected
            .where((reading) => reading.type == GlucoseType.fasting)
            .toList(growable: false);

        final postMeal = selected
            .where((reading) => reading.type == GlucoseType.postMeal)
            .toList(growable: false);

        final rangeLabel = _period == _SummaryPeriod.daily
            ? _date(today)
            : '${_date(start)} – ${_date(today)}';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DashboardCard(
              color: AppColors.lavender,
              onTap: widget.onOpenRecords,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _CardHeading(
                    icon: Icons.water_drop_outlined,
                    title: 'Son ölçüm',
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        latest == null ? 'Ölçüm yok' : '${latest.valueMgDl}',
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                      if (latest != null)
                        const Text(
                          'mg/dL',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    latest == null || latestDate == null
                        ? 'İlk ölçümünüzü Kayıtlar bölümünden ekleyin.'
                        : '${latest.type.label} • '
                              '${_date(latestDate)} ${_time(latestDate)}',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<_SummaryPeriod>(
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: AppColors.lavender,
                ),
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
            ),
            const SizedBox(height: 8),
            Text(
              '$rangeLabel • ${selected.length} ölçüm',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            _ResponsivePair(
              first: _AverageCard(
                title: 'Açlık ort.',
                icon: Icons.water_drop_outlined,
                value: _average(fasting),
                count: fasting.length,
                onTap: widget.onOpenRecords,
              ),
              second: _AverageCard(
                title: 'Tokluk ort.',
                icon: Icons.restaurant_outlined,
                value: _average(postMeal),
                count: postMeal.length,
                onTap: widget.onOpenRecords,
              ),
            ),
            const SizedBox(height: 12),
            _DashboardCard(
              onTap: widget.onOpenRecords,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _CardHeading(
                    icon: Icons.query_stats,
                    title: 'Genel ortalama',
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        selected.isEmpty ? 'Kayıt yok' : _average(selected),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                      if (selected.isNotEmpty)
                        const Text(
                          'mg/dL',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${selected.length} ölçüm • Açlık ve tokluk birlikte',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GlucoseSummaryChart(readings: selected),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      children: [
        Text(
          'Günlük takibiniz',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(color: AppColors.text, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          _date(now),
          style: const TextStyle(color: AppColors.muted, fontSize: 13),
        ),
        const SizedBox(height: 16),
        _buildGlucoseSection(),
        const SizedBox(height: 12),
        _ResponsivePair(
          first: LatestHba1cCard(
            key: ValueKey('latest-hba1c-${widget.userId}'),
            userId: widget.userId,
            onTap: widget.onOpenHba1c,
            compact: true,
          ),
          second: _DashboardCard(
            padding: 14,
            onTap: widget.onOpenReminders,
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CardHeading(icon: Icons.alarm_outlined, title: 'Hatırlatıcı'),
                SizedBox(height: 10),
                Text(
                  'Hazırlanıyor',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Hatırlatıcılar bölümü',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        TodayInsulinCard(
          key: ValueKey('today-insulin-${widget.userId}'),
          userId: widget.userId,
          onTap: widget.onOpenInsulin,
        ),
      ],
    );
  }
}

class _ResponsivePair extends StatelessWidget {
  const _ResponsivePair({required this.first, required this.second});

  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final largeText = MediaQuery.textScalerOf(context).scale(14) > 19;

        if (constraints.maxWidth < 320 || largeText) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [first, const SizedBox(height: 12), second],
          );
        }

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: first),
              const SizedBox(width: 12),
              Expanded(child: second),
            ],
          ),
        );
      },
    );
  }
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({
    required this.child,
    this.onTap,
    this.color = Colors.white,
    this.padding = 16,
  });

  final Widget child;
  final VoidCallback? onTap;
  final Color color;
  final double padding;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: EdgeInsets.all(padding), child: child),
      ),
    );
  }
}

class _CardHeading extends StatelessWidget {
  const _CardHeading({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const Icon(Icons.chevron_right, size: 18, color: AppColors.muted),
      ],
    );
  }
}

class _AverageCard extends StatelessWidget {
  const _AverageCard({
    required this.title,
    required this.icon,
    required this.value,
    required this.count,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final String value;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _DashboardCard(
      padding: 14,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeading(icon: icon, title: title),
          const SizedBox(height: 10),
          Wrap(
            spacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              if (count > 0)
                const Text(
                  'mg/dL',
                  style: TextStyle(color: AppColors.muted, fontSize: 11),
                ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            '$count ölçüm',
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
