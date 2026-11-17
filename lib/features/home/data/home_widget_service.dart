import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:home_widget/home_widget.dart';

import '../../../core/notifications/notification_service.dart';
import '../../glucose/domain/glucose_reading.dart';
import '../../reminders/data/reminder_repository.dart';
import '../../reminders/domain/reminder.dart';

class HomeWidgetService with WidgetsBindingObserver {
  HomeWidgetService._();

  static final HomeWidgetService instance = HomeWidgetService._();

  static const _storageKey = 'diabetes_widget_snapshot';
  static const _provider = 'com.example.track_diabetes.DiabetesWidgetProvider';

  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _notifications = FlutterLocalNotificationsPlugin();

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _glucoseSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _todaySubscription;
  StreamSubscription<List<Reminder>>? _reminderSubscription;

  Timer? _timer;

  Future<void> _writeQueue = Future<void>.value();

  bool _initialized = false;
  bool _sessionKnown = false;
  bool _paused = false;

  String? _userId;
  String? _dayKey;

  int _generation = 0;
  int _dayRevision = 0;

  GlucoseReading? _reading;
  List<Reminder> _reminders = [];
  List<Map<String, dynamic>> _todayReadings = [];

  bool _glucoseReady = false;
  bool _glucoseError = false;
  bool _todayReady = false;
  bool _todayError = false;
  bool _reminderReady = false;
  bool _reminderError = false;

  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> initialize() async {
    if (!isSupported || _initialized) return;

    _initialized = true;
    _paused = false;

    WidgetsBinding.instance.addObserver(this);

    NotificationService.instance.scheduleChanges.addListener(
      _onScheduleChanged,
    );

    _authSubscription = _auth.authStateChanges().listen(
      (user) {
        unawaited(_switchUserSafely(user));
      },
      onError: (Object error) {
        debugPrint('Widget oturumu alınamadı: $error');
      },
    );

    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!_paused && _userId != null) {
        unawaited(refresh());
      }
    });

    await _switchUserSafely(_auth.currentUser);
  }

  Future<void> _switchUserSafely(User? user) async {
    try {
      await _switchUser(user);
    } catch (error, stackTrace) {
      debugPrint('Widget oturumu güncellenemedi: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _switchUser(User? user, {bool force = false}) async {
    if (_paused && user != null) return;

    final userId = user?.uid;

    if (!force && _sessionKnown && _userId == userId) return;

    _sessionKnown = true;

    if (user == null) {
      _paused = false;
    }

    final generation = ++_generation;

    _userId = userId;
    _resetData();

    await _cancelDataSubscriptions();

    if (generation != _generation) return;

    await refresh();

    if (userId == null || !_isCurrent(generation, userId)) return;

    _glucoseSubscription = _firestore
        .collection('users')
        .doc(userId)
        .collection('glucose_readings')
        .orderBy('measuredAt', descending: true)
        .limit(1)
        .snapshots()
        .listen(
          (snapshot) {
            if (!_isCurrent(generation, userId)) return;

            try {
              _reading = snapshot.docs.isEmpty
                  ? null
                  : GlucoseReading.fromDocument(snapshot.docs.first);

              _glucoseReady = true;
              _glucoseError = false;
            } catch (error) {
              _reading = null;
              _glucoseReady = true;
              _glucoseError = true;
              debugPrint('Widget ölçümü okunamadı: $error');
            }

            unawaited(refresh());
          },
          onError: (Object error) {
            if (!_isCurrent(generation, userId)) return;

            _reading = null;
            _glucoseReady = true;
            _glucoseError = true;

            debugPrint('Widget ölçümü alınamadı: $error');
            unawaited(refresh());
          },
        );

    _reminderSubscription = ReminderRepository(userId: userId)
        .watchReminders()
        .listen(
          (reminders) {
            if (!_isCurrent(generation, userId)) return;

            _reminders = reminders;
            _reminderReady = true;
            _reminderError = false;

            unawaited(refresh());
          },
          onError: (Object error) {
            if (!_isCurrent(generation, userId)) return;

            _reminders = [];
            _reminderReady = true;
            _reminderError = true;

            debugPrint('Widget hatırlatıcıları alınamadı: $error');
            unawaited(refresh());
          },
        );
  }

  Future<void> _watchTodayIfNeeded() async {
    final userId = _userId;
    final generation = _generation;

    if (userId == null || !_isCurrent(generation, userId)) return;

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = DateTime(now.year, now.month, now.day + 1);

    // Saat dilimi değişirse sorgu sınırları da değişir.
    final dayKey =
        '${start.millisecondsSinceEpoch}:${end.millisecondsSinceEpoch}';

    if (_dayKey == dayKey) return;

    _dayKey = dayKey;
    final revision = ++_dayRevision;

    _todayReadings = [];
    _todayReady = false;
    _todayError = false;

    final oldSubscription = _todaySubscription;
    _todaySubscription = null;

    await oldSubscription?.cancel();

    bool isCurrent() {
      return _isCurrent(generation, userId) && revision == _dayRevision;
    }

    if (!isCurrent()) return;

    _todaySubscription = _firestore
        .collection('users')
        .doc(userId)
        .collection('glucose_readings')
        .where('measuredAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('measuredAt', isLessThan: Timestamp.fromDate(end))
        .snapshots()
        .listen(
          (snapshot) {
            if (!isCurrent()) return;

            try {
              _todayReadings = snapshot.docs.map((document) {
                final reading = GlucoseReading.fromDocument(document);

                return <String, dynamic>{
                  'valueMgDl': reading.valueMgDl,
                  'measuredAtMs': reading.measuredAt.millisecondsSinceEpoch,
                };
              }).toList();

              _todayReady = true;
              _todayError = false;
            } catch (error) {
              _todayReadings = [];
              _todayReady = true;
              _todayError = true;

              debugPrint('Widget günlük ölçümleri okunamadı: $error');
            }

            unawaited(refresh());
          },
          onError: (Object error) {
            if (!isCurrent()) return;

            _todayReadings = [];
            _todayReady = true;
            _todayError = true;

            debugPrint('Widget günlük ölçümleri alınamadı: $error');
            unawaited(refresh());
          },
        );
  }

  bool _isCurrent(int generation, String userId) {
    return generation == _generation &&
        !_paused &&
        _userId == userId &&
        _auth.currentUser?.uid == userId;
  }

  void _onScheduleChanged() {
    if (!_paused && _userId != null) {
      unawaited(refresh());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_paused) {
      unawaited(refresh());
    }
  }

  Future<void> refresh() async {
    if (!isSupported || _paused) return;

    try {
      await _watchTodayIfNeeded();

      if (_paused) return;

      await _publish();
    } catch (error, stackTrace) {
      debugPrint('Ana ekran widget güncellenemedi: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _publish({bool forceClear = false}) {
    final generation = _generation;
    final userId = _userId;
    final reading = _reading;

    final activeReminders = _reminders
        .where((reminder) => reminder.isEnabled)
        .toList();

    final snapshot = <String, dynamic>{
      'signedIn': !forceClear && userId != null,
      'glucoseReady': _glucoseReady,
      'glucoseError': _glucoseError,
      'todayReady': _todayReady,
      'todayError': _todayError,
      'reminderReady': _reminderReady,
      'reminderError': _reminderError,
      'reading': forceClear || reading == null
          ? null
          : {
              'valueMgDl': reading.valueMgDl,
              'type': reading.type.code,
              'measuredAtMs': reading.measuredAt.millisecondsSinceEpoch,
            },
      'todayReadings': forceClear
          ? <Map<String, dynamic>>[]
          : List<Map<String, dynamic>>.of(_todayReadings),
      'reminders': forceClear
          ? <Map<String, dynamic>>[]
          : activeReminders.map((reminder) {
              return <String, dynamic>{
                'id': reminder.id,
                'type': reminder.type.code,
                'hour': reminder.hour,
                'minute': reminder.minute,
                'weekdays': reminder.weekdays,
              };
            }).toList(),
    };

    bool isCurrent() {
      if (generation != _generation) return false;
      if (forceClear) return true;

      return !_paused && _auth.currentUser?.uid == userId;
    }

    final result = _writeQueue.then((_) async {
      if (!isCurrent()) return;

      final snoozes = <Map<String, dynamic>>[];

      if (!forceClear && userId != null && activeReminders.isNotEmpty) {
        try {
          final pending = await _notifications.pendingNotificationRequests();

          final activeById = {
            for (final reminder in activeReminders) reminder.id: reminder,
          };

          for (final notification in pending) {
            final data = NotificationService.parseReminderPayload(
              notification.payload,
            );

            if (data == null ||
                data['kind'] != 'snooze' ||
                data['userId'] != userId) {
              continue;
            }

            final reminder = activeById[data['reminderId']];
            final scheduledAtMs = data['scheduledAtMs'];

            if (reminder == null || scheduledAtMs is! int) continue;

            final key = NotificationService.scheduleKey(
              type: reminder.type.code,
              hour: reminder.hour,
              minute: reminder.minute,
              weekdays: reminder.weekdays,
              note: reminder.note,
            );

            if (data['scheduleKey'] != key) continue;

            snoozes.add({
              'type': reminder.type.code,
              'scheduledAtMs': scheduledAtMs,
            });
          }
        } catch (error) {
          debugPrint('Widget erteleme bilgisi alınamadı: $error');
        }
      }

      if (!isCurrent()) return;

      snapshot['snoozes'] = snoozes;
      snapshot['writtenAtMs'] = DateTime.now().millisecondsSinceEpoch;

      final saved = await HomeWidget.saveWidgetData<String>(
        _storageKey,
        jsonEncode(snapshot),
      );

      if (saved != true) {
        throw StateError('Widget verisi kaydedilemedi.');
      }

      await HomeWidget.updateWidget(qualifiedAndroidName: _provider);
    });

    _writeQueue = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );

    return result;
  }

  void _resetData() {
    ++_dayRevision;

    _dayKey = null;
    _reading = null;
    _reminders = [];
    _todayReadings = [];

    _glucoseReady = false;
    _glucoseError = false;
    _todayReady = false;
    _todayError = false;
    _reminderReady = false;
    _reminderError = false;
  }

  Future<void> _cancelDataSubscriptions() async {
    final glucose = _glucoseSubscription;
    final today = _todaySubscription;
    final reminders = _reminderSubscription;

    _glucoseSubscription = null;
    _todaySubscription = null;
    _reminderSubscription = null;

    await glucose?.cancel();
    await today?.cancel();
    await reminders?.cancel();
  }

  Future<void> suspendAndClear() async {
    if (!isSupported) return;

    _paused = true;
    ++_generation;

    _resetData();

    await _cancelDataSubscriptions();
    await _publish(forceClear: true);
  }

  Future<void> resume() async {
    if (!isSupported) return;

    _paused = false;

    await _switchUser(_auth.currentUser, force: true);
  }

  Future<void> dispose() async {
    if (!_initialized) return;

    _initialized = false;
    _paused = true;
    ++_generation;

    WidgetsBinding.instance.removeObserver(this);

    NotificationService.instance.scheduleChanges.removeListener(
      _onScheduleChanged,
    );

    _timer?.cancel();
    _timer = null;

    final authSubscription = _authSubscription;
    _authSubscription = null;

    await authSubscription?.cancel();
    await _cancelDataSubscriptions();
    await _writeQueue;

    _userId = null;
    _sessionKnown = false;
    _resetData();
  }
}
