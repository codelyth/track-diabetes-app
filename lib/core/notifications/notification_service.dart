import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'notification_occurrence.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const reminderPayloadPrefix = 'diabetes-reminder:';
  static const snoozeActionId = 'snooze_10_minutes';
  static const openActionId = 'open_record';
  static const completeInsulinActionId = 'complete_insulin';
  static const skipInsulinActionId = 'skip_insulin';

  static const snoozeDuration = Duration(minutes: 10);

  static const _instantTestId = 900001;
  static const _scheduledTestId = 900002;
  static const _feedbackId = 900003;

  static const reservedIds = {_instantTestId, _scheduledTestId, _feedbackId};

  static const _actionChannel = MethodChannel(
    'track_diabetes/notification_actions',
  );

  final ValueNotifier<String?> pendingPayload = ValueNotifier<String?>(null);

  final ValueNotifier<int> scheduleChanges = ValueNotifier<int>(0);

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void>? _initialization;
  Future<void> _queue = Future<void>.value();

  bool _launchDetailsRead = false;
  bool _sessionWasSet = false;

  String? _sessionUserId;
  int _sessionVersion = 0;

  final Set<String> _processingActions = {};

  static const _testChannel = AndroidNotificationChannel(
    'reminder_tests_v1',
    'Bildirim testleri',
    description:
        'Hatırlatıcı altyapısını kontrol etmek için test bildirimleri.',
    importance: Importance.high,
  );

  static const _testDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'reminder_tests_v1',
      'Bildirim testleri',
      channelDescription:
          'Hatırlatıcı altyapısını kontrol etmek için test bildirimleri.',
      icon: 'ic_notification',
      importance: Importance.high,
      priority: Priority.high,
      visibility: NotificationVisibility.private,
      autoCancel: true,
    ),
  );

  static const reminderDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'diabetes_reminders_v1',
      'Takip hatırlatıcıları',
      channelDescription: 'Ölçüm ve insülin takip hatırlatıcıları.',
      icon: 'ic_notification',
      importance: Importance.high,
      priority: Priority.high,
      visibility: NotificationVisibility.private,
      autoCancel: true,
      actions: [
        AndroidNotificationAction(
          openActionId,
          'Kaydı aç',
          showsUserInterface: true,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          snoozeActionId,
          '10 dakika ertele',
          showsUserInterface: true,
          cancelNotification: false,
        ),
      ],
    ),
  );

  static const insulinReminderDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'diabetes_reminders_v1',
      'Takip hatırlatıcıları',
      channelDescription: 'Ölçüm ve insülin takip hatırlatıcıları.',
      icon: 'ic_notification',
      importance: Importance.high,
      priority: Priority.high,
      visibility: NotificationVisibility.private,
      autoCancel: true,
      actions: [
        AndroidNotificationAction(
          completeInsulinActionId,
          'Yapıldı',
          showsUserInterface: true,
          cancelNotification: false,
        ),
        AndroidNotificationAction(
          skipInsulinActionId,
          'Atlandı',
          showsUserInterface: true,
          cancelNotification: false,
        ),
        AndroidNotificationAction(
          snoozeActionId,
          '10 dk ertele',
          showsUserInterface: true,
          cancelNotification: false,
        ),
      ],
    ),
  );

  static const _feedbackDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'notification_status_v1',
      'Bildirim işlem sonuçları',
      channelDescription: 'Erteleme işlemlerinin sonuçları.',
      icon: 'ic_notification',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      playSound: false,
      enableVibration: false,
      visibility: NotificationVisibility.private,
      autoCancel: true,
    ),
  );

  static NotificationDetails detailsForType(String type) {
    return type == 'insulin' ? insulinReminderDetails : reminderDetails;
  }

  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  AndroidFlutterLocalNotificationsPlugin get _android {
    final implementation = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (implementation == null) {
      throw StateError('Android bildirim servisine ulaşılamadı.');
    }

    return implementation;
  }

  void notifyScheduleChanges() {
    scheduleChanges.value++;
  }

  void setSessionUser(String? userId) {
    _sessionWasSet = true;

    if (_sessionUserId != userId) {
      _sessionVersion++;
      _sessionUserId = userId;
    }
  }

  Future<T> runExclusive<T>(Future<T> Function() operation) {
    final result = _queue.then((_) => operation());

    _queue = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );

    return result;
  }

  Future<void> initialize() async {
    if (!isSupported) {
      throw UnsupportedError(
        'Bu bildirim altyapısı şu anda Android için hazırlanmıştır.',
      );
    }

    final initialization = _initialization ??= _initialize();

    try {
      await initialization;
    } catch (_) {
      _initialization = null;
      rethrow;
    }
  }

  Future<void> _initialize() async {
    if (!_sessionWasSet) {
      setSessionUser(FirebaseAuth.instance.currentUser?.uid);
    }

    final initialized = await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
      ),
      onDidReceiveNotificationResponse: (response) {
        unawaited(_dispatchResponse(response));
      },
    );

    if (initialized != true) {
      throw StateError('Bildirim servisi başlatılamadı.');
    }

    await _android.createNotificationChannel(_testChannel);

    tz_data.initializeTimeZones();

    if (!_launchDetailsRead) {
      final details = await _plugin.getNotificationAppLaunchDetails();
      _launchDetailsRead = true;

      final response = details?.notificationResponse;

      if (details?.didNotificationLaunchApp == true && response != null) {
        // Başlatma işleminin kendisini beklemesini önler.
        unawaited(_dispatchResponse(response));
      }
    }
  }

  Future<void> _dispatchResponse(NotificationResponse response) async {
    if (parseReminderPayload(response.payload) == null) return;

    try {
      final claimed = await _actionChannel.invokeMethod<bool>(
        'consumeNotificationAction',
        {
          'notificationId': response.id,
          'payload': response.payload,
          'actionId': response.actionId ?? '',
        },
      );

      if (claimed != true) {
        debugPrint(
          '[BİLDİRİM] Başlangıç işlemi zaten tüketilmiş '
          'veya güncel bildirimle eşleşmiyor. Tekrar çalıştırılmadı.',
        );

        return;
      }

      await _handleResponse(response);
    } catch (error, stackTrace) {
      debugPrint('Bildirim işlemi başlatılamadı: $error');
      debugPrintStack(stackTrace: stackTrace);

      await _showFeedback(
        title: 'Bildirim işlemi tamamlanamadı',
        body:
            'Uygulamayı tamamen kapatıp yeniden açın. '
            'Ardından bildirimdeki düğmeden tekrar deneyin.',
      );
    }
  }

  Future<void> _handleResponse(NotificationResponse response) async {
    final payload = response.payload;
    final data = parseReminderPayload(payload);

    if (data == null) return;

    final actionId = response.actionId;

    // Erteleme doğrudan çalışır; tarih seçimi açılmaz.
    if (actionId == snoozeActionId) {
      final actionKey = '${response.id}:$payload';

      if (!_processingActions.add(actionKey)) return;

      try {
        if (data['type'] == 'insulin') {
          await snoozeInsulin(data: {...data, 'notificationId': response.id});
        } else {
          await initialize();
          await _snooze(response);
        }
      } catch (error, stackTrace) {
        debugPrint('Erteleme başarısız: $error');
        debugPrintStack(stackTrace: stackTrace);

        final message = error is StateError
            ? error.message.toString()
            : 'Hatırlatıcı ertelenemedi. Bağlantınızı kontrol edip '
                  'bildirimdeki düğmeden tekrar deneyin.';

        await _showFeedback(title: 'Erteleme tamamlanamadı', body: message);
      } finally {
        _processingActions.remove(actionKey);
      }

      return;
    }

    if (data['type'] == 'insulin') {
      final String action;

      if (actionId == completeInsulinActionId) {
        action = 'complete';
      } else if (actionId == skipInsulinActionId) {
        action = 'skip';
      } else if (actionId == null ||
          actionId.isEmpty ||
          actionId == openActionId) {
        action = 'open';
      } else {
        return;
      }

      pendingPayload.value =
          '$reminderPayloadPrefix${jsonEncode({...data, 'action': action, 'notificationId': response.id})}';

      return;
    }

    if (actionId == null || actionId.isEmpty || actionId == openActionId) {
      pendingPayload.value = payload;
    }
  }

  static Map<String, dynamic>? parseReminderPayload(String? payload) {
    if (payload == null || !payload.startsWith(reminderPayloadPrefix)) {
      return null;
    }

    try {
      final decoded = jsonDecode(
        payload.substring(reminderPayloadPrefix.length),
      );

      if (decoded is! Map<String, dynamic>) return null;

      final userId = decoded['userId'];
      final reminderId = decoded['reminderId'];

      if (userId is! String ||
          userId.isEmpty ||
          reminderId is! String ||
          reminderId.isEmpty ||
          reminderId.contains('/')) {
        return null;
      }

      return decoded;
    } catch (_) {
      return null;
    }
  }

  static String scheduleKey({
    required String type,
    required int hour,
    required int minute,
    required List<int> weekdays,
    required String note,
  }) {
    final days = weekdays.toSet().toList()..sort();

    return jsonEncode([type, hour, minute, days, note.trim()]);
  }

  static String reminderBody(String type) {
    return switch (type) {
      'fasting' => 'Açlık ölçümü hatırlatıcınızın zamanı geldi.',
      'postMeal' => 'Tokluk ölçümü hatırlatıcınızın zamanı geldi.',
      'insulin' => 'İnsülin takip hatırlatıcınızın zamanı geldi.',
      _ => throw StateError('Hatırlatıcı türü tanınamadı.'),
    };
  }

  Future<DateTime> snoozeInsulin({required Map<String, dynamic> data}) async {
    try {
      await initialize();

      final userId = data['userId'];
      final reminderId = data['reminderId'];

      if (data['type'] != 'insulin' ||
          userId is! String ||
          reminderId is! String) {
        throw StateError('İnsülin bildirimi doğrulanamadı.');
      }

      final occurrence = NotificationOccurrence.read(
        data['occurrence'],
        reminderId: reminderId,
      );

      if (data['occurrence'] != null && occurrence == null) {
        throw StateError('İnsülin planının bilgileri doğrulanamadı.');
      }

      final sessionVersion = _sessionVersion;

      bool isCurrentSession() {
        return sessionVersion == _sessionVersion &&
            _sessionUserId == userId &&
            FirebaseAuth.instance.currentUser?.uid == userId;
      }

      if (!isCurrentSession()) {
        throw StateError('Oturum değişti. Erteleme yapılmadı.');
      }

      final notificationId = data['notificationId'];

      debugPrint('[İNSÜLİN ERTELEME] İşlem başladı.');

      await _snooze(
        NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotificationAction,
          id: notificationId is int ? notificationId : null,
          actionId: snoozeActionId,
          payload: '$reminderPayloadPrefix${jsonEncode(data)}',
        ),
      );

      if (!isCurrentSession()) {
        throw StateError('Oturum değişti. Erteleme doğrulanamadı.');
      }

      final pending = await _plugin.pendingNotificationRequests();

      if (!isCurrentSession()) {
        throw StateError('Oturum değişti. Erteleme doğrulanamadı.');
      }

      for (final item in pending) {
        final saved = parseReminderPayload(item.payload);

        if (saved == null ||
            saved['kind'] != 'snooze' ||
            saved['type'] != 'insulin' ||
            saved['userId'] != userId ||
            saved['reminderId'] != reminderId ||
            saved['scheduleKey'] != data['scheduleKey']) {
          continue;
        }

        final savedOccurrence = NotificationOccurrence.read(
          saved['occurrence'],
          reminderId: reminderId,
        );

        if (occurrence != null) {
          if (savedOccurrence?.id != occurrence.id) continue;
        } else {
          if (saved['snoozeScope'] != 'reminder' ||
              saved['occurrence'] != null) {
            continue;
          }
        }

        final scheduledAtMs = saved['scheduledAtMs'];

        if (scheduledAtMs is! int) continue;

        final scheduledAt = DateTime.fromMillisecondsSinceEpoch(scheduledAtMs);

        if (!scheduledAt.isAfter(DateTime.now())) continue;

        debugPrint(
          '[İNSÜLİN ERTELEME] '
          'cihazdaKayitli=true '
          'id=${item.id} '
          'planlanan=$scheduledAt',
        );

        return scheduledAt;
      }

      throw StateError(
        'Ertelemenin cihazda kayıtlı olduğu doğrulanamadı. '
        'Hatırlatıcılar bölümünü yenileyip tekrar kontrol edin.',
      );
    } catch (error, stackTrace) {
      debugPrint('[İNSÜLİN ERTELEME] Başarısız: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> acknowledgeInsulinOccurrence({
    required String userId,
    required String occurrenceId,
    required bool skipped,
    int? notificationId,
  }) async {
    await initialize();

    final version = _sessionVersion;

    bool isCurrentSession() {
      return version == _sessionVersion &&
          _sessionUserId == userId &&
          FirebaseAuth.instance.currentUser?.uid == userId;
    }

    await runExclusive(() async {
      if (!isCurrentSession()) return;

      final pending = await _plugin.pendingNotificationRequests();

      for (final item in pending) {
        if (!isCurrentSession()) return;

        final data = parseReminderPayload(item.payload);

        if (data == null ||
            data['kind'] != 'snooze' ||
            data['type'] != 'insulin' ||
            data['userId'] != userId) {
          continue;
        }

        final target = NotificationOccurrence.read(
          data['occurrence'],
          reminderId: data['reminderId'] as String,
        );

        final isOpenedReminderSnooze =
            data['snoozeScope'] == 'reminder' &&
            data['occurrence'] == null &&
            item.id == notificationId;

        if (target?.id == occurrenceId || isOpenedReminderSnooze) {
          await _plugin.cancel(id: item.id);
        }
      }

      if (!isCurrentSession()) return;

      notifyScheduleChanges();

      // Haftalık tekrarın kimliği doğrudan iptal edilmez.
      await _showFeedback(
        id: notificationId,
        title: 'İnsülin takibi güncellendi',
        body: skipped
            ? 'Seçilen plan atlandı olarak işaretlendi.'
            : 'Uygulama kaydedildi ve seçilen plan tamamlandı.',
      );
    });
  }

  Future<void> _snooze(NotificationResponse response) {
    final user = FirebaseAuth.instance.currentUser;
    final data = parseReminderPayload(response.payload);

    if (user == null || data == null || data['userId'] != user.uid) {
      throw StateError('Bu bildirim mevcut hesaba ait değil.');
    }

    final userId = user.uid;
    final version = _sessionVersion;

    bool isCurrentSession() {
      return version == _sessionVersion &&
          _sessionUserId == userId &&
          FirebaseAuth.instance.currentUser?.uid == userId;
    }

    return runExclusive(() async {
      if (!isCurrentSession()) {
        throw StateError('Oturum değişti. Erteleme yapılmadı.');
      }

      final reminderId = data['reminderId'] as String;

      final deletion = await FirebaseFirestore.instance
          .collection('account_deletions')
          .doc(userId)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 10));

      if (!isCurrentSession()) {
        throw StateError('Oturum değişti. Erteleme yapılmadı.');
      }

      if (deletion.exists) {
        throw StateError('Bu hesap için silme işlemi başlatılmış.');
      }

      final document = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('reminders')
          .doc(reminderId)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 10));

      if (!isCurrentSession()) {
        throw StateError('Oturum değişti. Erteleme yapılmadı.');
      }

      final reminder = document.data();

      if (!document.exists ||
          reminder == null ||
          reminder['isEnabled'] != true) {
        throw StateError('Bu hatırlatıcı silinmiş veya kapatılmış.');
      }

      final type = reminder['type'] as String;

      final currentKey = scheduleKey(
        type: type,
        hour: reminder['hour'] as int,
        minute: reminder['minute'] as int,
        weekdays: List<int>.from(reminder['weekdays'] as List),
        note: reminder['note'] as String,
      );

      final originalKey = data['scheduleKey'];

      if (originalKey != null && originalKey != currentKey) {
        throw StateError(
          'Hatırlatıcı değiştirilmiş. Güncel kaydı '
          'Hatırlatıcılar bölümünden kontrol edin.',
        );
      }

      NotificationOccurrence? occurrence;

      if (type == 'insulin') {
        if (data['version'] != 2 ||
            data['type'] != 'insulin' ||
            originalKey != currentKey) {
          throw StateError(
            'İnsülin bildirimi güncel hatırlatıcıyla eşleşmiyor.',
          );
        }

        final encodedOccurrence = data['occurrence'];

        if (encodedOccurrence == null) {
          final validSource =
              data['kind'] == 'regular' ||
              (data['kind'] == 'snooze' && data['snoozeScope'] == 'reminder');

          final weekdays = List<int>.from(reminder['weekdays'] as List);
          final timeZoneId = data['timeZoneId'];

          if (!validSource ||
              data['hour'] != reminder['hour'] ||
              data['minute'] != reminder['minute'] ||
              !weekdays.contains(data['weekday']) ||
              timeZoneId is! String) {
            throw StateError('İnsülin bildiriminin bilgileri doğrulanamadı.');
          }

          NotificationOccurrence.locationFor(timeZoneId);
        } else {
          occurrence = NotificationOccurrence.read(
            encodedOccurrence,
            reminderId: reminderId,
          );

          if (occurrence == null) {
            throw StateError('İnsülin planının bilgileri doğrulanamadı.');
          }

          final weekdays = List<int>.from(reminder['weekdays'] as List);
          final createdAt = reminder['createdAt'];
          final updatedAt = reminder['updatedAt'];

          if (occurrence.hour != reminder['hour'] ||
              occurrence.minute != reminder['minute'] ||
              !weekdays.contains(occurrence.weekday) ||
              occurrence.scheduledAt.isAfter(DateTime.now()) ||
              createdAt is! Timestamp ||
              updatedAt is! Timestamp ||
              createdAt.toDate().isAfter(occurrence.scheduledAt) ||
              updatedAt.toDate().isAfter(occurrence.scheduledAt)) {
            throw StateError(
              'Bu plan artık geçerli değil. Güncel takibi kontrol edin.',
            );
          }

          final saved = await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('insulin_occurrences')
              .doc(occurrence.id)
              .get(const GetOptions(source: Source.server))
              .timeout(const Duration(seconds: 10));

          if (saved.exists) {
            throw StateError('Bu plan zaten işaretlenmiş. Tekrar ertelenmedi.');
          }
        }
      }

      if (!isCurrentSession()) {
        throw StateError('Oturum değişti. Erteleme yapılmadı.');
      }

      if (!await notificationsEnabled()) {
        throw StateError('Bildirim izni kapalı. Erteleme yapılamadı.');
      }

      final pending = await _plugin.pendingNotificationRequests();

      int? existingId;

      for (final item in pending) {
        final itemData = parseReminderPayload(item.payload);

        if (itemData?['kind'] != 'snooze' ||
            itemData?['userId'] != userId ||
            itemData?['reminderId'] != reminderId) {
          continue;
        }

        if (occurrence != null) {
          final existingOccurrence = NotificationOccurrence.read(
            itemData?['occurrence'],
            reminderId: reminderId,
          );

          if (existingOccurrence?.id != occurrence.id) continue;
        } else if (type == 'insulin') {
          if (itemData?['occurrence'] != null ||
              itemData?['snoozeScope'] != 'reminder') {
            continue;
          }
        }

        existingId = item.id;
        break;
      }

      // Bekleyen insülin ertelemesinin saati tekrar ileri taşınmaz.
      if (type == 'insulin' && existingId != null) {
        final existing = pending.firstWhere((item) => item.id == existingId);

        final existingData = parseReminderPayload(existing.payload);
        final existingTimeMs = existingData?['scheduledAtMs'];

        if (existingData?['type'] == 'insulin' &&
            existingData?['scheduleKey'] == currentKey &&
            existingTimeMs is int &&
            existingTimeMs > DateTime.now().millisecondsSinceEpoch) {
          if (!isCurrentSession()) {
            throw StateError('Oturum değişti. Erteleme doğrulanamadı.');
          }

          final existingDate = DateTime.fromMillisecondsSinceEpoch(
            existingTimeMs,
          );

          final hour = existingDate.hour.toString().padLeft(2, '0');
          final minute = existingDate.minute.toString().padLeft(2, '0');

          debugPrint(
            '[ERTELEME KORUNDU] '
            'id=$existingId '
            'planlanan=$existingDate '
            'yenidenZamanlandi=false',
          );

          notifyScheduleChanges();

          await _showFeedback(
            id: response.id,
            title: 'Hatırlatıcı zaten ertelendi',
            body:
                'Mevcut bildirim saati: $hour:$minute. '
                'Erteleme saati değiştirilmedi.',
          );

          return;
        }
      }

      final usedIds = pending.map((item) => item.id).toSet()
        ..addAll(reservedIds);

      final scope = occurrence?.id ?? reminderId;

      var id = existingId ?? (1000000000 + stableHash('$userId/$scope/snooze'));

      if (existingId == null) {
        while (usedIds.contains(id)) {
          id = id >= 1999999999 ? 1000000000 : id + 1;
        }
      }

      final exact = await exactAlarmsEnabled();

      if (!isCurrentSession()) {
        throw StateError('Oturum değişti. Erteleme yapılmadı.');
      }

      final scheduledDate = tz.TZDateTime.now(tz.UTC).add(snoozeDuration);

      final payloadData = <String, dynamic>{
        ...data,
        'version': 2,
        'userId': userId,
        'reminderId': reminderId,
        'type': type,
        'kind': 'snooze',
        'scheduleKey': currentKey,
        'scheduledAtMs': scheduledDate.millisecondsSinceEpoch,
      };

      payloadData.remove('action');
      payloadData.remove('notificationId');

      if (occurrence != null) {
        payloadData['occurrence'] = occurrence.toMap();
        payloadData.remove('snoozeScope');
      } else if (type == 'insulin') {
        payloadData.remove('occurrence');
        payloadData['snoozeScope'] = 'reminder';
      }

      final payload = '$reminderPayloadPrefix${jsonEncode(payloadData)}';

      var approximate = !exact;

      Future<void> schedule(AndroidScheduleMode mode) {
        return _plugin.zonedSchedule(
          id: id,
          title: 'Şeker Takibi',
          body: reminderBody(type),
          scheduledDate: scheduledDate,
          notificationDetails: detailsForType(type),
          androidScheduleMode: mode,
          payload: payload,
        );
      }

      try {
        await schedule(
          exact
              ? AndroidScheduleMode.exactAllowWhileIdle
              : AndroidScheduleMode.inexactAllowWhileIdle,
        );
      } on PlatformException catch (error) {
        if (error.code != 'exact_alarms_not_permitted') rethrow;

        approximate = true;

        await schedule(AndroidScheduleMode.inexactAllowWhileIdle);
      }

      if (!isCurrentSession()) {
        await _plugin.cancel(id: id);
        throw StateError('Oturum değişti. Erteleme iptal edildi.');
      }

      notifyScheduleChanges();

      debugPrint(
        '[ERTELEME] id=$id '
        'planlanan=$scheduledDate '
        'plan=${occurrence?.id} '
        'yaklasik=$approximate',
      );

      final localDate = scheduledDate.toLocal();
      final hour = localDate.hour.toString().padLeft(2, '0');
      final minute = localDate.minute.toString().padLeft(2, '0');

      await _showFeedback(
        id: response.id,
        title: 'Hatırlatıcı ertelendi',
        body: approximate
            ? 'Yaklaşık 10 dakika sonrasına planlandı. '
                  'Android bildirimi geciktirebilir.'
            : 'Sonraki bildirim: $hour:$minute. '
                  'Normal tekrar saatiniz değişmedi.',
      );
    });
  }

  Future<void> _showFeedback({
    int? id,
    required String title,
    required String body,
  }) async {
    try {
      await _plugin.show(
        id: id ?? _feedbackId,
        title: title,
        body: body,
        notificationDetails: _feedbackDetails,
      );
    } catch (error) {
      debugPrint('Bildirim işlem sonucu gösterilemedi: $error');
    }
  }

  static int stableHash(String value) {
    var hash = 0;

    for (final codeUnit in value.codeUnits) {
      hash = (hash * 31 + codeUnit) % 1000000000;
    }

    return hash;
  }

  String? takePendingPayload() {
    final payload = pendingPayload.value;
    pendingPayload.value = null;
    return payload;
  }

  void clearPendingPayload() {
    pendingPayload.value = null;
  }

  Future<bool> notificationsEnabled() async {
    await initialize();
    return await _android.areNotificationsEnabled() ?? false;
  }

  Future<bool> requestNotificationPermission() async {
    await initialize();
    await _android.requestNotificationsPermission();

    return await _android.areNotificationsEnabled() ?? false;
  }

  Future<bool> exactAlarmsEnabled() async {
    await initialize();
    return await _android.canScheduleExactNotifications() ?? false;
  }

  Future<void> requestExactAlarmPermission() async {
    await initialize();
    await _android.requestExactAlarmsPermission();
  }

  Future<void> openNotificationSettings() async {
    await initialize();
    await _android.openAppNotificationSettings();
  }

  Future<void> _ensureNotificationPermission() async {
    if (!await notificationsEnabled()) {
      throw StateError(
        'Bildirim izni kapalı. Önce bildirim iznini etkinleştirin.',
      );
    }
  }

  Future<void> showTestNotification() async {
    await initialize();
    await _ensureNotificationPermission();

    await _plugin.show(
      id: _instantTestId,
      title: 'Bildirim testi',
      body: 'Şeker Takibi bildirim servisi çalışıyor.',
      notificationDetails: _testDetails,
    );
  }

  Future<bool> scheduleTestNotification() async {
    await initialize();
    await _ensureNotificationPermission();

    tz_data.initializeTimeZones();

    final timezone = await FlutterTimezone.getLocalTimezone();
    final identifier = timezone.identifier.trim();

    final location = switch (identifier) {
      'GMT' || 'Etc/GMT' || 'UTC' || 'Etc/UTC' => tz.UTC,
      _ => tz.getLocation(identifier),
    };

    final scheduledDate = tz.TZDateTime.now(location)
        .add(const Duration(minutes: 1));

    final useExactAlarm = await exactAlarmsEnabled();

    await _plugin.zonedSchedule(
      id: _scheduledTestId,
      title: 'Zamanlanmış bildirim testi',
      body: 'Arka plan bildirim testi tamamlandı.',
      scheduledDate: scheduledDate,
      notificationDetails: _testDetails,
      androidScheduleMode: useExactAlarm
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
    );

    return useExactAlarm;
  }

  Future<void> cancelTestNotifications() async {
    if (!isSupported) return;

    await initialize();

    await _plugin.cancel(id: _instantTestId);
    await _plugin.cancel(id: _scheduledTestId);
  }
}
