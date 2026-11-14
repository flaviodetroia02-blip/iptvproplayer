import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models.dart';

// Calendario da TheSportsDB (chiave gratuita di prova).
const _leagues = {'4332': 'Serie A', '4480': 'Champions League'};

String _d(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime? _start(Map e) {
  final ts = e['strTimestamp']?.toString() ?? '';
  if (ts.isNotEmpty) {
    final t = DateTime.tryParse(ts.endsWith('Z') || ts.contains('+') ? ts : '${ts}Z');
    if (t != null) return t.toLocal();
  }
  final d = e['dateEvent'];
  final t = e['strTime'];
  if (d != null && t != null) return DateTime.tryParse('${d}T${t}Z')?.toLocal();
  return null;
}

/// Partite di oggi e dei prossimi due giorni (più quelle iniziate da meno di 2 ore).
Future<List<Match>> fetchMatches() async {
  final now = DateTime.now();
  final seen = <String>{};
  final out = <Match>[];
  for (var i = 0; i < 3; i++) {
    final day = _d(now.add(Duration(days: i)));
    for (final id in _leagues.keys) {
      try {
        final r = await http
            .get(Uri.parse(
                'https://www.thesportsdb.com/api/v1/json/3/eventsday.php?d=$day&l=$id'))
            .timeout(const Duration(seconds: 15));
        if (r.statusCode != 200) continue;
        final events = jsonDecode(utf8.decode(r.bodyBytes))['events'];
        if (events is! List) continue;
        for (final e in events) {
          if ('${e['idLeague']}' != id) continue;
          final s = _start(e);
          final home = '${e['strHomeTeam'] ?? ''}';
          final away = '${e['strAwayTeam'] ?? ''}';
          if (s == null || home.isEmpty || away.isEmpty) continue;
          if (s.isBefore(now.subtract(const Duration(hours: 2)))) continue;
          if (!seen.add('$home-$away-${s.millisecondsSinceEpoch}')) continue;
          out.add(Match(home: home, away: away, league: _leagues[id]!, cup: id == '4480', start: s));
        }
      } catch (_) {}
    }
  }
  out.sort((a, b) => a.start.compareTo(b.start));
  return out;
}

/// Canali sportivi presenti nella playlist dell'utente, in ordine di probabilità.
List<Item> sportsChannels(List<Item> live, {required bool cup}) {
  final keys = cup
      ? ['sky sport', 'prime video', 'canale 5', 'italia 1', 'dazn']
      : ['dazn', 'sky sport', 'sky calcio', 'eleven'];
  final scored = <MapEntry<int, Item>>[];
  for (final c in live) {
    final n = c.name.toLowerCase();
    final idx = keys.indexWhere((k) => n.contains(k));
    if (idx >= 0) scored.add(MapEntry(idx, c));
  }
  scored.sort((a, b) =>
      a.key != b.key ? a.key.compareTo(b.key) : a.value.name.compareTo(b.value.name));
  return [for (final e in scored.take(16)) e.value];
}

const _popular = [
  'rai 1', 'canale 5', 'rai 2', 'italia 1', 'sky uno',
  'sky cinema uno', 'sky sport uno', 'sky tg24', 'rai 3', 'rete 4',
];

/// Canali generalisti e Sky tra i più seguiti in Italia, se presenti nella playlist.
List<Item> popularChannels(List<Item> live) {
  final out = <Item>[];
  for (final k in _popular) {
    final found = live.where((c) => c.name.toLowerCase().contains(k)).toList();
    if (found.isEmpty) continue;
    found.sort((a, b) => a.name.length.compareTo(b.name.length));
    out.add(found.first);
  }
  return out;
}
