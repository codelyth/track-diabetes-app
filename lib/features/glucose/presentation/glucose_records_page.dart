import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/glucose_repository.dart';
import '../domain/glucose_reading.dart';

enum _Period {
  today('Bugün'),
  week('Son 7 Gün'),
  month('Son 30 Gün'),
  custom('Özel Aralık');

  const _Period(this.label);

  final String label;
}

class GlucoseRecordsPage extends StatefulWidget {
  const GlucoseRecordsPage({super.key, required this.userId});

  final String userId;

  @override
  State<GlucoseRecordsPage> createState() => _GlucoseRecordsPageState();
}

class _GlucoseRecordsPageState extends State<GlucoseRecordsPage> {
  late final GlucoseRepository _repository;
  late Stream<List<GlucoseReading>> _readingsStream;

  _Period _period = _Period.week;
  GlucoseType? _type;
  DateTimeRange? _customRange;

  @override
  void initState() {
    super.initState();

    _repository = GlucoseRepository(userId: widget.userId);
    _readingsStream = _repository.watchReadings();
  }

  String _two(int value) => value.toString().padLeft(2, '0');

  String _date(DateTime value) {
    return '${_two(value.day)}.${_two(value.month)}.${value.year}';
  }

  String _time(DateTime value) {
    return '${_two(value.hour)}:${_two(value.minute)}';
  }

  DateTimeRange get _range {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (_period == _Period.custom && _customRange != null) {
      return _customRange!;
    }

    final days = switch (_period) {
      _Period.today => 1,
      _Period.week => 7,
      _Period.month => 30,
      _Period.custom => 7,
    };

    return DateTimeRange(
      start: DateTime(today.year, today.month, today.day - days + 1),
      end: today,
    );
  }

  Future<void> _selectPeriod(_Period period) async {
    if (period != _Period.custom) {
      setState(() => _period = period);
      return;
    }

    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange: _customRange ?? _range,
      helpText: 'Tarih aralığını seçin',
      cancelText: 'İptal',
      confirmText: 'Seç',
      saveText: 'Uygula',
    );

    if (selected == null || !mounted) return;

    setState(() {
      _customRange = selected;
      _period = _Period.custom;
    });
  }

  List<GlucoseReading> _filter(
    List<GlucoseReading> readings,
    DateTimeRange range,
  ) {
    final endExclusive = DateTime(
      range.end.year,
      range.end.month,
      range.end.day + 1,
    );

    return readings
        .where((reading) {
          final measuredAt = reading.measuredAt.toLocal();

          return !measuredAt.isBefore(range.start) &&
              measuredAt.isBefore(endExclusive) &&
              (_type == null || reading.type == _type);
        })
        .toList(growable: false);
  }

  void _showDetails(GlucoseReading reading) {
    final measuredAt = reading.measuredAt.toLocal();

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
                  '${reading.valueMgDl} mg/dL',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${reading.type.label} • '
                  '${_date(measuredAt)} • ${_time(measuredAt)}',
                ),
                const SizedBox(height: 24),
                Text('Not', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  reading.note.isEmpty ? 'Not eklenmemiş.' : reading.note,
                  style: const TextStyle(height: 1.5),
                ),
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
    final range = _range;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      children: [
        Text(
          'Şeker ölçümleri',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _Period.values.map((period) {
            return ChoiceChip(
              label: Text(period.label),
              selected: _period == period,
              onSelected: (_) => _selectPeriod(period),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'all', label: Text('Tümü')),
            ButtonSegment(value: 'fasting', label: Text('Açlık')),
            ButtonSegment(value: 'postMeal', label: Text('Tokluk')),
          ],
          selected: {_type?.code ?? 'all'},
          onSelectionChanged: (selection) {
            setState(() {
              final code = selection.first;
              _type = code == 'all' ? null : GlucoseType.fromCode(code);
            });
          },
        ),
        const SizedBox(height: 16),
        Text(
          '${_date(range.start)} – ${_date(range.end)}',
          style: const TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 16),
        StreamBuilder<List<GlucoseReading>>(
          stream: _readingsStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Column(
                children: [
                  const Text(
                    'Kayıtlar yüklenemedi. Bağlantınızı ve erişim '
                    'izinlerinizi kontrol edin.',
                    textAlign: TextAlign.center,
                  ),
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
              );
            }

            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final readings = _filter(snapshot.data!, range);

            if (readings.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.search_off, size: 40, color: AppColors.primary),
                    SizedBox(height: 12),
                    Text(
                      'Bu aralıkta kayıt yok',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Tarih veya ölçüm türü filtresini değiştirebilirsiniz.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${readings.length} ölçüm • '
                  '${_type?.label ?? 'Tüm türler'}',
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 12),
                Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minWidth: constraints.maxWidth,
                          ),
                          child: DataTable(
                            horizontalMargin: 12,
                            columnSpacing: 16,
                            showCheckboxColumn: false,
                            headingRowColor: const WidgetStatePropertyAll(
                              AppColors.lavender,
                            ),
                            columns: const [
                              DataColumn(label: Text('Tarih')),
                              DataColumn(label: Text('Saat')),
                              DataColumn(label: Text('Tür')),
                              DataColumn(label: Text('mg/dL'), numeric: true),
                            ],
                            rows: readings.map((reading) {
                              final date = reading.measuredAt.toLocal();

                              return DataRow(
                                onSelectChanged: (_) => _showDetails(reading),
                                cells: [
                                  DataCell(Text(_date(date))),
                                  DataCell(Text(_time(date))),
                                  DataCell(Text(reading.type.label)),
                                  DataCell(
                                    Text(
                                      '${reading.valueMgDl}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Detay için bir satıra dokunun. '
                  'Tablo sığmazsa yatay kaydırabilirsiniz.',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
