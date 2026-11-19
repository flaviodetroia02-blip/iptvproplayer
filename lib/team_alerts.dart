import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_state.dart';

class TeamAlerts {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _init = false;

  static Future<void> init() async {
    if (_init || kIsWeb) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(const InitializationSettings(android: android, iOS: ios));
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (_) {}
    _init = true;
  }

  static Future<Set<String>> _shown() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList('notifiedMatches') ?? []).toSet();
  }

  static Future<void> _saveShown(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    final l = ids.toList();
    if (l.length > 200) l.removeRange(0, l.length - 200);
    await prefs.setStringList('notifiedMatches', l);
  }

  static Future<void> check(AppState s) async {
    if (kIsWeb) return;
    final team = s.favoriteTeam?.toLowerCase();
    if ((team == null || team.isEmpty) && !s.nationalTeam) return;

    try {
      await init();
      final shown = await _shown();
      final now = DateTime.now();
      var added = false;

      for (final m in s.matches) {
        if (m.start.isBefore(now)) continue;
        if (m.start.isAfter(now.add(const Duration(days: 3)))) continue;

        final home = m.home.toLowerCase();
        final away = m.away.toLowerCase();
        final isFav = team != null &&
            team.isNotEmpty &&
            (home.contains(team) || away.contains(team));
        final isNaz = s.nationalTeam && (home.contains('italia') || away.contains('italia'));
        if (!isFav && !isNaz) continue;

        final key = '${m.home}-${m.away}-${m.start.millisecondsSinceEpoch}';
        if (shown.contains(key)) continue;
        shown.add(key);
        added = true;

        await _plugin.show(
          key.hashCode & 0x7fffffff,
          isNaz ? 'Nazionale' : 'Squadra del cuore',
          '${m.home} - ${m.away} · ${m.when}',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'teams',
              'Partite squadra del cuore',
              channelDescription: 'Notifiche partite della squadra preferita e della Nazionale',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
        );
      }

      if (added) await _saveShown(shown);
    } catch (_) {}
  }
}
