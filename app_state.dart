import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'm3u.dart';
import 'models.dart';
import 'sports.dart';
import 'xtream.dart';

class AppState extends ChangeNotifier {
  late SharedPreferences _prefs;
  bool ready = false, loading = false;
  String? error;
  Map<String, dynamic>? source;
  List<Item> live = [], movies = [], series = [];
  Set<String> favorites = {};
  List<Match> matches = [];
  List<Item> recents = [];
  Map<String, int> positions = {};

  bool get loggedIn => source != null;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    favorites = (_prefs.getStringList('fav') ?? []).toSet();
    final r = _prefs.getString('recents');
    if (r != null) {
      recents = [for (final j in jsonDecode(r) as List) Item.fromJson(j as Map<String, dynamic>)];
    }
    final p = _prefs.getString('pos');
    if (p != null) {
      positions = (jsonDecode(p) as Map<String, dynamic>).map((k, v) => MapEntry(k, v as int));
    }
    final saved = _prefs.getString('source');
    if (saved != null) {
      source = jsonDecode(saved) as Map<String, dynamic>;
      await _load(source!);
    }
    ready = true;
    notifyListeners();
  }

  Future<void> connectM3u(String url) => _connect({'type': 'm3u', 'url': url.trim()});

  Future<void> connectXtream(String server, String user, String pass) =>
      _connect({'type': 'xtream', 'server': server.trim(), 'user': user.trim(), 'pass': pass});

  Future<void> _connect(Map<String, dynamic> s) async {
    if (await _load(s)) {
      source = s;
      await _prefs.setString('source', jsonEncode(s));
      notifyListeners();
    }
  }

  Future<bool> reload() => _load(source!);

  Future<List<Item>> _safe(Future<List<Item>> Function() f) async {
    try {
      return await f();
    } catch (_) {
      return [];
    }
  }

  Future<bool> _load(Map<String, dynamic> s) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      List<Item> l, m, se;
      if (s['type'] == 'm3u') {
        final r = await http.get(Uri.parse(s['url'] as String)).timeout(const Duration(seconds: 60));
        if (r.statusCode != 200) throw Exception('Risposta ${r.statusCode}');
        final all = parseM3u(utf8.decode(r.bodyBytes, allowMalformed: true));
        l = all.where((i) => i.kind == Kind.live).toList();
        m = all.where((i) => i.kind == Kind.movie).toList();
        se = all.where((i) => i.kind == Kind.series).toList();
      } else {
        final x = XtreamClient(s['server'] as String, s['user'] as String, s['pass'] as String);
        l = await _safe(x.live);
        m = await _safe(x.movies);
        se = await _safe(x.series);
      }
      if (l.isEmpty && m.isEmpty && se.isEmpty) throw Exception('vuota');
      live = l;
      movies = m;
      series = se;
      loading = false;
      notifyListeners();
      _refreshMatches();
      return true;
    } catch (_) {
      error = kIsWeb
          ? 'Caricamento non riuscito. Il browser blocca spesso queste richieste: usa la versione Windows o Android.'
          : 'Caricamento non riuscito. Controlla link o credenziali e la connessione.';
      loading = false;
      notifyListeners();
      return false;
    }
  }

  void _refreshMatches() {
    fetchMatches().then((m) {
      matches = m;
      notifyListeners();
    });
  }

  void markWatched(Item i) {
    recents.removeWhere((r) => r.id == i.id);
    recents.insert(0, i);
    if (recents.length > 20) recents = recents.sublist(0, 20);
    _prefs.setString('recents', jsonEncode([for (final r in recents) r.toJson()]));
    Future.microtask(notifyListeners);
  }

  int positionOf(String url) => positions[url] ?? 0;

  void savePosition(String url, int sec, int total) {
    if (total > 0 && sec >= total - 60) {
      positions.remove(url);
    } else if (sec > 10) {
      positions[url] = sec;
    }
    _prefs.setString('pos', jsonEncode(positions));
  }

  Future<void> logout() async {
    await _prefs.remove('source');
    source = null;
    live = [];
    movies = [];
    series = [];
    error = null;
    notifyListeners();
  }

  List<Item> itemsOf(Kind k) => k == Kind.live ? live : (k == Kind.movie ? movies : series);

  bool isFav(Item i) => favorites.contains(i.id);

  void toggleFav(Item i) {
    if (!favorites.remove(i.id)) favorites.add(i.id);
    _prefs.setStringList('fav', favorites.toList());
    notifyListeners();
  }

  List<Item> get favoriteLive => live.where(isFav).toList();

  Future<List<Episode>> episodes(Item s) {
    final x = XtreamClient(
        source!['server'] as String, source!['user'] as String, source!['pass'] as String);
    return x.episodes(s.seriesId!);
  }

  Map<String, List<Item>> grouped(List<Item> items, {int maxGroups = 14, int perGroup = 24}) {
    final m = <String, List<Item>>{};
    for (final i in items) {
      (m[i.group] ??= []).add(i);
    }
    return {for (final e in m.entries.take(maxGroups)) e.key: e.value.take(perGroup).toList()};
  }
}
