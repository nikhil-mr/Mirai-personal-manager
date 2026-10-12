import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

enum ReminderAvailability { scheduled, approximate, denied, unsupported }

class ReminderResult {
  const ReminderResult(this.availability, {this.message});
  final ReminderAvailability availability;
  final String? message;
  bool get scheduled =>
      availability == ReminderAvailability.scheduled ||
      availability == ReminderAvailability.approximate;
}

abstract interface class TaskReminderService {
  Future<void> initialize();
  Future<ReminderResult> schedule({
    required int notificationId,
    required String taskId,
    required String title,
    required DateTime reminderAt,
    required String soundId,
    bool requestPermission = true,
  });
  Future<void> cancel(int notificationId);
  Future<void> reconcile(List<TaskReminderEntry> tasks);
}

class TaskReminderEntry {
  const TaskReminderEntry({
    required this.id,
    required this.notificationId,
    required this.title,
    required this.reminderAt,
    required this.reminderEnabled,
    required this.isCompleted,
    required this.soundId,
  });
  final String id;
  final int? notificationId;
  final String title;
  final DateTime? reminderAt;
  final bool reminderEnabled;
  final bool isCompleted;
  final String soundId;
}

class LocalTaskReminderService implements TaskReminderService {
  LocalTaskReminderService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();
  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;
  bool _exactAlarmsAllowed = false;

  bool get supportsScheduling =>
      !kIsWeb && defaultTargetPlatform != TargetPlatform.linux;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    try {
      final local = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(local.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
      macOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
      linux: LinuxInitializationSettings(
        defaultActionName: 'Open Mirai',
      ),
      windows: WindowsInitializationSettings(
        appName: 'Mirai',
        appUserModelId: 'com.example.personal_manager',
        guid: 'a073eb08-4364-4b92-9db2-4f32a102b70c',
      ),
      web: WebInitializationSettings(),
    );
    await _plugin.initialize(settings: settings);
    _initialized = true;
  }

  Future<ReminderResult> requestPermission() async {
    await initialize();
    if (kIsWeb) {
      return const ReminderResult(
        ReminderAvailability.unsupported,
        message: 'Browsers cannot deliver scheduled reminders while Mirai is closed.',
      );
    }
    if (defaultTargetPlatform == TargetPlatform.linux) {
      return const ReminderResult(
        ReminderAvailability.unsupported,
        message: 'Scheduled notifications are not supported on Linux by the current notification backend.',
      );
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final notifications = await android?.requestNotificationsPermission();
      if (notifications == false) {
        return const ReminderResult(
          ReminderAvailability.denied,
          message: 'Notification permission was not granted.',
        );
      }
      _exactAlarmsAllowed =
          await android?.requestExactAlarmsPermission() ?? false;
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      final granted = await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      if (granted == false) {
        return const ReminderResult(
          ReminderAvailability.denied,
          message: 'Notification permission was not granted.',
        );
      }
    } else if (defaultTargetPlatform == TargetPlatform.macOS) {
      final granted = await _plugin
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      if (granted == false) {
        return const ReminderResult(
          ReminderAvailability.denied,
          message: 'Notification permission was not granted.',
        );
      }
    }
    return ReminderResult(
      defaultTargetPlatform == TargetPlatform.android && !_exactAlarmsAllowed
          ? ReminderAvailability.approximate
          : ReminderAvailability.scheduled,
      message:
          defaultTargetPlatform == TargetPlatform.android &&
              !_exactAlarmsAllowed
          ? 'Exact alarm access was not granted; Android may deliver this reminder later than requested.'
          : null,
    );
  }

  @override
  Future<ReminderResult> schedule({
    required int notificationId,
    required String taskId,
    required String title,
    required DateTime reminderAt,
    required String soundId,
    bool requestPermission = true,
  }) async {
    final permission = requestPermission
        ? await this.requestPermission()
        : await _existingPermission();
    if (!permission.scheduled) return permission;
    if (!reminderAt.isAfter(DateTime.now())) {
      return const ReminderResult(
        ReminderAvailability.denied,
        message: 'Choose a reminder time in the future.',
      );
    }
    final sound = soundId != 'silent';
    final channel = sound ? 'task_reminders_default' : 'task_reminders_silent';
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channel,
        sound ? 'Task reminders' : 'Silent task reminders',
        channelDescription: sound
            ? 'Scheduled reminders for Mirai tasks.'
            : 'Silent scheduled reminders for Mirai tasks.',
        importance: Importance.high,
        priority: Priority.high,
        playSound: sound,
      ),
      iOS: DarwinNotificationDetails(presentSound: sound),
      macOS: DarwinNotificationDetails(presentSound: sound),
      windows: WindowsNotificationDetails(
        audio: sound
            ? WindowsNotificationAudio.preset(
                sound: WindowsNotificationSound.defaultSound,
              )
            : WindowsNotificationAudio.silent(),
      ),
    );
    await _plugin.zonedSchedule(
      id: notificationId,
      title: 'Mirai task reminder',
      body: title,
      scheduledDate: tz.TZDateTime.from(reminderAt.toLocal(), tz.local),
      notificationDetails: details,
      androidScheduleMode: _exactAlarmsAllowed
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      payload: taskId,
    );
    return permission;
  }

  Future<ReminderResult> _existingPermission() async {
    await initialize();
    if (!supportsScheduling) {
      return const ReminderResult(ReminderAvailability.unsupported);
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (await android?.areNotificationsEnabled() == false) {
        return const ReminderResult(ReminderAvailability.denied);
      }
      _exactAlarmsAllowed =
          await android?.canScheduleExactNotifications() ?? false;
    }
    return ReminderResult(
      defaultTargetPlatform == TargetPlatform.android && !_exactAlarmsAllowed
          ? ReminderAvailability.approximate
          : ReminderAvailability.scheduled,
    );
  }

  @override
  Future<void> cancel(int notificationId) async {
    await initialize();
    await _plugin.cancel(id: notificationId);
  }

  @override
  Future<void> reconcile(List<TaskReminderEntry> tasks) async {
    await initialize();
    if (!supportsScheduling) return;
    final activeIds = <int>{};
    for (final task in tasks) {
      final id = task.notificationId;
      final at = task.reminderAt;
      if (!task.reminderEnabled ||
          task.isCompleted ||
          id == null ||
          at == null ||
          !at.isAfter(DateTime.now())) {
        if (id != null) await cancel(id);
        continue;
      }
      activeIds.add(id);
      await schedule(
        notificationId: id,
        taskId: task.id,
        title: task.title,
        reminderAt: at,
        soundId: task.soundId,
        requestPermission: false,
      );
    }
    if (defaultTargetPlatform != TargetPlatform.windows) {
      final pending = await _plugin.pendingNotificationRequests();
      for (final request in pending) {
        if (!activeIds.contains(request.id)) await cancel(request.id);
      }
    }
  }
}
