import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/notifications/notification_occurrence.dart';
import '../../../core/notifications/notification_service.dart';
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

class _NextReminderCardState extends State<NextReminderCard>
    with WidgetsBindingObserver {
  final _notifications = NotificationService.instance;
  final _plugin = FlutterLocalNotificationsPlugin();

  late Stream<List<Reminder>> _stream;

  List<PendingNotificationRequest> _pending = [];

  Timer? _refreshTimer;
  int _loadVersion = 0;

  bool _loadingSnoozes = true;
  bool _snoozeError = false;

  @override
  void initState() {
    super.initState();

    _stream = ReminderRepository(userId: widget.userId).watchReminders();

    WidgetsBinding.instance.addObserver(this);
    _notifications.scheduleChanges.addListener(_onScheduleChanged);

    unawaited(_loadSnoozes());

    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(_loadSnoozes()),
    );
  }

  @override
  void didUpdateWidget(covariant NextReminderCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.userId != widget.userId) {
      _loadVersion++;

      _stream = ReminderRepository(userId: widget.userId).watchReminders();

      _pending = [];
      _loadingSnoozes = true;
      _snoozeError = false;

      unawaited(_loadSnoozes());
    }
  }

  void _onScheduleChanged() {
    unawaited(_loadSnoozes());
  }

  Future<void> _loadSnoozes() async {
    final version = ++_loadVersion;
    final userId = widget.userId;

    try {
      List<PendingNotificationRequest> pending = [];

      if (_notifications.isSupported) {
        await _notifications.initialize();
        pending = await _plugin.pendingNotificationRequests();
      }

      if (!mounted || version != _loadVersion || userId != widget.userId) {
        return;
      }

      setState(() {
        _pending = pending;
        _loadingSnoozes = false;
        _snoozeError = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Özet ekranı ertelemeleri alınamadı: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted || version != _loadVersion || userId != widget.userId) {
        return;
      }

      setState(() {
        _pending = [];
        _loadingSnoozes = false;
        _snoozeError = true;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_loadSnoozes());
    }
  }

  @override
  void dispose() {
    _loadVersion++;
    _refreshTimer?.cancel();

    _notifications.scheduleChanges.removeListener(_onScheduleChanged);
    WidgetsBinding.instance.removeObserver(this);

    super.dispose();
  }

  String _scheduleKey(Reminder reminder) {
    return NotificationService.scheduleKey(
      type: reminder.type.code,
      hour: reminder.hour,
      minute: reminder.minute,
      weekdays: reminder.weekdays,
      note: reminder.note,
    );
  }

  tz.TZDateTime? _snoozeDate({
    required Map<String, dynamic> data,
    required Reminder reminder,
    required tz.Location location,
    required DateTime now,
  }) {
    try {
      if (!reminder.isEnabled ||
          data['kind'] != 'snooze' ||
          data['userId'] != widget.userId ||
          data['reminderId'] != reminder.id ||
          data['type'] != reminder.type.code ||
          data['scheduleKey'] != _scheduleKey(reminder)) {
        return null;
      }

      final milliseconds = data['scheduledAtMs'];

      if (milliseconds is! int || milliseconds <= now.millisecondsSinceEpoch) {
        return null;
      }

      if (reminder.type == ReminderType.insulin) {
        if (data['version'] != 2) return null;

        final encodedOccurrence = data['occurrence'];

        if (encodedOccurrence != null) {
          final occurrence = NotificationOccurrence.read(
            encodedOccurrence,
            reminderId: reminder.id,
          );

          if (occurrence == null ||
              occurrence.hour != reminder.hour ||
              occurrence.minute != reminder.minute ||
              !reminder.weekdays.contains(occurrence.weekday)) {
            return null;
          }
        } else {
          final timeZoneId = data['timeZoneId'];

          if (data['snoozeScope'] != 'reminder' ||
              data['hour'] != reminder.hour ||
              data['minute'] != reminder.minute ||
              !reminder.weekdays.contains(data['weekday']) ||
              timeZoneId is! String) {
            return null;
          }

          NotificationOccurrence.locationFor(timeZoneId);
        }
      }

      return tz.TZDateTime.fromMillisecondsSinceEpoch(location, milliseconds);
    } catch (error) {
      debugPrint('Geçersiz erteleme özette gösterilmedi: $error');
      return null;
    }
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

            var isSnoozed = false;

            if (snapshot.hasError) {
              title = 'Alınamadı';
              subtitle = 'Hatırlatıcıları kontrol edin';
            } else if (clockError) {
              title = 'Saat alınamadı';
              subtitle = 'Cihazın saat dilimini kontrol edin';
            } else if (snapshot.hasData &&
                location != null &&
                !_loadingSnoozes) {
              final reminders = snapshot.data!;
              final now = tz.TZDateTime.now(location);

              final activeById = {
                for (final reminder in reminders)
                  if (reminder.isEnabled) reminder.id: reminder,
              };

              Reminder? nextReminder;
              tz.TZDateTime? nextDate;

              // Normal tekrarların en yakın olanını bul.
              for (final reminder in activeById.values) {
                final candidate = ReminderTime.nextOccurrence(
                  reminder: reminder,
                  location: location,
                );

                if (candidate == null || !candidate.isAfter(now)) {
                  continue;
                }

                if (nextDate == null || candidate.isBefore(nextDate)) {
                  nextReminder = reminder;
                  nextDate = candidate;
                  isSnoozed = false;
                }
              }

              // Cihazdaki geçerli ertelemeleri normal tekrarlarla karşılaştır.
              for (final notification in _pending) {
                final data = NotificationService.parseReminderPayload(
                  notification.payload,
                );

                if (data == null) continue;

                final reminder = activeById[data['reminderId']];

                if (reminder == null) continue;

                final candidate = _snoozeDate(
                  data: data,
                  reminder: reminder,
                  location: location,
                  now: now,
                );

                if (candidate == null) continue;

                if (nextDate == null ||
                    candidate.isBefore(nextDate) ||
                    (!isSnoozed && candidate.isAtSameMomentAs(nextDate))) {
                  nextReminder = reminder;
                  nextDate = candidate;
                  isSnoozed = true;
                }
              }

              if (nextReminder == null || nextDate == null) {
                title = 'Plan yok';
                subtitle = 'Aktif hatırlatıcı ekleyin';
              } else {
                title = ReminderTime.time(nextDate);
                subtitle = nextReminder.type.label;
                date = ReminderTime.date(nextDate);

                footer = isSnoozed
                    ? 'Erteleme zamanı · 24 saat'
                    : 'Planlanan · 24 saat';
              }

              if (_snoozeError) {
                footer = 'Ertelemeler kontrol edilemedi';
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
                      Row(
                        children: [
                          Icon(
                            isSnoozed
                                ? Icons.snooze_outlined
                                : Icons.alarm_outlined,
                            size: 20,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 7),
                          const Expanded(
                            child: Text(
                              'Hatırlatıcı',
                              style: TextStyle(
                                fontSize: AppTypography.cardTitleSize,
                                color: AppColors.text,
                                fontWeight: FontWeight.w600,
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
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: AppTypography.metricCompactSize,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: AppTypography.captionSize,
                        ),
                      ),
                      if (date != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          date,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: AppTypography.captionSize,
                          ),
                        ),
                      ],
                      if (isSnoozed) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.lavender,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.snooze_outlined,
                                size: 14,
                                color: AppColors.primary,
                              ),
                              SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  'Ertelendi',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: AppTypography.captionSize,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (footer != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          footer,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: AppTypography.captionSize,
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
        style: TextStyle(
          color: AppColors.muted,
          fontSize: AppTypography.captionSize,
        ),
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
            fontSize: AppTypography.captionSize,
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
    _loadVersion++;
    _timer?.cancel();

    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _location, _error);
  }
}
