import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/note.dart';

/// Schedules local notifications for note reminders.
///
/// Only active on Android. On Windows/Linux/macOS/Web this is a no-op —
/// reminders are stored in Firestore so they show up on the phone,
/// but the desktop won't fire system notifications. That's intentional:
/// the phone is where you actually want reminders to go off.
class ReminderService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static bool _supported = false;

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    if (kIsWeb || !Platform.isAndroid) {
      _supported = false;
      return;
    }

    tz_data.initializeTimeZones();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidInit);
    await _plugin.initialize(settings);

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();

    _supported = true;
  }

  static int _idForNote(String noteId) => noteId.hashCode & 0x7fffffff;

  static Future<void> cancelForNote(String noteId) async {
    if (!_supported) return;
    await _plugin.cancel(_idForNote(noteId));
  }

  static Future<void> scheduleForNote(Note note) async {
    if (!_supported) return;
    await cancelForNote(note.id);
    final at = note.reminderAt;
    if (at == null) return;
    if (at.isBefore(DateTime.now())) return;

    final scheduled = tz.TZDateTime.from(at, tz.local);

    const androidDetails = AndroidNotificationDetails(
      'cardtrove_companion_reminders',
      'Reminders',
      channelDescription: 'Note and checklist reminders',
      importance: Importance.high,
      priority: Priority.high,
    );

    final title = note.title.isEmpty ? 'Reminder' : note.title;
    final body = note.type == NoteType.checklist
        ? '${note.items.where((i) => !i.done).length} items remaining'
        : (note.body.isEmpty ? 'Tap to open' : note.body);

    await _plugin.zonedSchedule(
      _idForNote(note.id),
      title,
      body,
      scheduled,
      const NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> syncAll(List<Note> notes) async {
    if (!_supported) return;
    await _plugin.cancelAll();
    for (final n in notes) {
      if (n.reminderAt != null) {
        await scheduleForNote(n);
      }
    }
  }
}
