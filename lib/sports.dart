import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models.dart';

// Calendario da TheSportsDB (chiave gratuita di prova).
const _leagueNames = {
  '4332': 'Serie A',
  '4480': 'Champions League',
  '4481': 'Europa League',
  '5071': 'Conference League',
};
const _leagueBonus = {'4332': 0, '4480': 4, '4481': 3, '5071': 1};
const _leagueTag = {'4332': 'a', '4480': 'eu', '4481': 'eu', '5071': 'eu'};

// Peso delle squadre: le italiane più importanti valgono di più.
const _teams = {
  'juventus': 11, 'inter': 11, 'milan': 11, 'napoli': 10, 'roma': 9,
  'atalanta': 9, 'lazio': 8, 'fiorentina': 6, 'bologna': 5, 'torino': 4,
  'real madrid': 9, 'barcelona': 9, 'bayern': 9, 'manchester city': 9,
  'liverpool': 8, 'arsenal': 8, 'paris': 8, 'psg': 8, 'chelsea': 7,
  'manchester united': 7, 'madrid': 7, 'dortmund': 7, 'tottenham': 6,
  'leverkusen': 6, 'benfica': 5, 'porto': 5, 'aston villa': 5,
  'newcastle': 4, 'ajax': 4, 'sporting': 4,
};

const _nations = {
  'italy', 'brazil', 'argentina', 'france', 'england', 'spain', 'germany',
  'portugal', 'netherlands', 'belgium', 'croatia',
};

int _teamScore(String name) {
  final n = name.toLowerCase();
  var best = 0;
  for (final e in _teams.entries) {
    if (n.contains(e.key) && e.value > best) best = e.value;
  }
  return best;
}

String? _img(dynamic v) {
  final s = v?.toString() ?? '';
  return s.startsWith('http') ? s : null;
}

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

Future<List<Fixture>> _day(String day, String query, DateTime now, {String? leagueId}) async {
  try {
    final r = await http
        .get(Uri.parse(
            'https://www.thesportsdb.com/api/v1/json/3/eventsday.php?d=$day&$query'))
        .timeout(const Duration(seconds: 15));
    if (r.statusCode != 200) return [];
    final events = jsonDecode(utf8.decode(r.bodyBytes))['events'];
    if (events is! List) return [];
    final out = <Fixture>[];
    for (final e in events) {
      final home = '${e['strHomeTeam'] ?? ''}';
      final away = '${e['strAwayTeam'] ?? ''}';
      final s = _start(e);
      if (s == null || home.isEmpty || away.isEmpty) continue;
      if (s.isBefore(now.subtract(const Duration(hours: 2)))) continue;
      final lid = '${e['idLeague']}';
      if (_leagueNames.containsKey(lid)) {
        out.add(Fixture(
          home: home,
          away: away,
          league: _leagueNames[lid]!,
          tag: _leagueTag[lid]!,
          start: s,
          score: _teamScore(home) + _teamScore(away) + _leagueBonus[lid]!,
          homeBadge: _img(e['strHomeTeamBadge']),
          awayBadge: _img(e['strAwayTeamBadge']),
        ));
      } else if (leagueId == null) {
        // Nazionali: l'Italia, oppure sfide tra grandi nazionali.
        final h = home.toLowerCase();
        final a = away.toLowerCase();
        final italy = h == 'italy' || a == 'italy';
        final big = _nations.contains(h) && _nations.contains(a);
        if (!italy && !big) continue;
        out.add(Fixture(
          home: home,
          away: away,
          league: '${e['strLeague'] ?? 'Nazionali'}',
          tag: 'nz',
          start: s,
          score: (italy ? 25 : 0) + (_nations.contains(h) ? 8 : 0) + (_nations.contains(a) ? 8 : 0),
          homeBadge: _img(e['strHomeTeamBadge']),
          awayBadge: _img(e['strAwayTeamBadge']),
        ));
      }
    }
    return out;
  } catch (_) {
    return [];
  }
}

/// Le partite più importanti di oggi e dei prossimi due giorni (max 8),
/// con in testa quelle delle grandi italiane, delle coppe europee e delle nazionali.
Future<List<Fixture>> fetchMatches() async {
  final now = DateTime.now();
  final jobs = <Future<List<Fixture>>>[];
  for (var i = 0; i < 3; i++) {
    final day = _d(now.add(Duration(days: i)));
    for (final id in _leagueNames.keys) {
      jobs.add(_day(day, 'l=$id', now, leagueId: id));
    }
    jobs.add(_day(day, 's=Soccer', now));
  }
  final seen = <String>{};
  final all = <Fixture>[];
  for (final list in await Future.wait(jobs)) {
    for (final m in list) {
      if (seen.add('${m.home}-${m.away}-${m.start.millisecondsSinceEpoch}')) all.add(m);
    }
  }
  all.sort((a, b) => b.score != a.score ? b.score.compareTo(a.score) : a.start.compareTo(b.start));
  return all.take(30).toList();
}

/// Canali sportivi presenti nella playlist dell'utente, in ordine di probabilità.
List<Item> sportsChannels(List<Item> live, String tag) {
  final keys = switch (tag) {
    'a' => ['dazn', 'sky sport', 'sky calcio', 'eleven'],
    'nz' => ['rai 1', 'sky sport', 'rai sport', 'dazn', 'canale 5', 'italia 1'],
    _ => ['sky sport', 'prime video', 'canale 5', 'italia 1', 'dazn'],
  };
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
