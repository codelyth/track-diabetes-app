import 'dart:async';

import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/theme/app_theme.dart';
import '../data/reminder_repository.dart';
import '../domain/reminder.dart';
import '../domain/reminder_time.dart';

class NextReminderCard extends StatefulWidget {
  const NextReminderCard({
    super.key,
    required this.userId,
    required this.onTap,
  });

  final String userId;
  final VoidCallback onTap;

  @override
  State<NextReminderCard> createState() => _NextReminderCardState();
}

class _NextReminderCardState extends State<NextReminderCard> {
  late final Stream<List<Reminder>> _stream;

  @override
  void initState() {
    super.initState();

    _stream = ReminderRepository(userId: widget.userId).watchReminders();
  }

  @override
  Widget build(BuildContext context) {
    return _ReminderClock(
      builder: (context, location, clockError) {
        return StreamBuilder<List<Reminder>>(
          stream: _stream,
          builder: (context, snapshot) {
            String title = 'Yükleniyor';
            String subtitle = 'Hatırlatıcılar kontrol ediliyor';
            String? date;
            String? footer;

            if (snapshot.hasError) {
              title = 'Alınamadı';
              subtitle = 'Hatırlatıcıları kontrol edin';
            } else if (clockError) {
              title = 'Saat alınamadı';
              subtitle = 'Cihazın saat dilimini kontrol edin';
            } else if (snapshot.hasData && location != null) {
              Reminder? nextReminder;
              tz.TZDateTime? nextDate;

              for (final reminder in snapshot.data!) {
                final candidate = ReminderTime.nextOccurrence(
                  reminder: reminder,
                  location: location,
                );

                if (candidate == null) continue;

                if (nextDate == null || candidate.isBefore(nextDate)) {
                  nextReminder = reminder;
                  nextDate = candidate;
                }
              }

              if (nextReminder == null || nextDate == null) {
                title = 'Plan yok';
                subtitle = 'Aktif hatırlatıcı ekleyin';
              } else {
                title = ReminderTime.time(nextDate);
                subtitle = nextReminder.type.label;
                date = ReminderTime.date(nextDate);
                footer = 'Planlanan · 24 saat';
              }
            }

            return Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: widget.onTap,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.alarm_outlined,
                            size: 20,
                            color: AppColors.primary,
                          ),
                          SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              'Hatırlatıcı',
                              style: TextStyle(
                                color: AppColors.text,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            size: 18,
                            color: AppColors.muted,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                      if (date != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          date,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      if (footer != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          footer,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class ReminderNextTime extends StatelessWidget {
  const ReminderNextTime({super.key, required this.reminder});

  final Reminder reminder;

  @override
  Widget build(BuildContext context) {
    if (!reminder.isEnabled) {
      return const Text(
        'Kapalı · Bildirim planlanmaz',
        style: TextStyle(color: AppColors.muted, fontSize: 12),
      );
    }

    return _ReminderClock(
      builder: (context, location, error) {
        String text;

        if (error) {
          text = 'Sonraki zaman hesaplanamadı.';
        } else if (location == null) {
          text = 'Sonraki zaman hesaplanıyor...';
        } else {
          final next = ReminderTime.nextOccurrence(
            reminder: reminder,
            location: location,
          );

          text = next == null
              ? 'Tekrar günü seçilmemiş.'
              : 'Sonraki plan: ${ReminderTime.label(next)} · 24 saat';
        }

        return Text(
          text,
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 12,
            height: 1.5,
          ),
        );
      },
    );
  }
}

class _ReminderClock extends StatefulWidget {
  const _ReminderClock({required this.builder});

  final Widget Function(BuildContext context, tz.Location? location, bool error)
  builder;

  @override
  State<_ReminderClock> createState() => _ReminderClockState();
}

class _ReminderClockState extends State<_ReminderClock>
    with WidgetsBindingObserver {
  tz.Location? _location;
  bool _error = false;

  Timer? _timer;
  int _loadVersion = 0;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
    unawaited(_loadLocation());

    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  Future<void> _loadLocation() async {
    final version = ++_loadVersion;

    try {
      final location = await ReminderTime.deviceLocation();

      if (!mounted || version != _loadVersion) return;

      setState(() {
        _location = location;
        _error = false;
      });
    } catch (error) {
      debugPrint('Hatırlatıcı saat dilimi alınamadı: $error');

      if (!mounted || version != _loadVersion) return;

      setState(() {
        _location = null;
        _error = true;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_loadLocation());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();

    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _location, _error);
  }
}
