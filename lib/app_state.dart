import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'cache.dart';
import 'device.dart';
import 'm3u.dart';
import 'models.dart';
import 'net.dart';
import 'sports.dart';
import 'widgets.dart' show setUiFactor;
import 'xtream.dart';

List<Item> _parseM3uBytes(Uint8List b) => parseM3u(utf8.decode(b, allowMalformed: true));

const _uiSizes = [0.9, 1.0, 1.15, 1.3];

class AppState extends ChangeNotifier {
  late SharedPreferences _prefs;
  bool ready = false, loading = false;
  String? error, refreshError;
  Map<String, dynamic>? source;
  List<Item> live = [], movies = [], series = [];
  Set<String> favorites = {};
  List<Fixture> matches = [];
  List<Item> recents = [];
  Map<String, int> positions = {}, durations = {};
  Map<String, String> prefChannel = {};
  int tab = 0;
  int _routes = 0;
  int cacheTime = 0;
  Map<String, Item> _liveById = {};

  // impostazioni
  bool previews = true, heroSound = false, slowWarn = true;
  int posterSecs = 5, heroMode = 0, fitMode = 0, bufferMode = 1, uiSize = 1, refreshHours = 6;
  List<String> heroIds = [];

  // misura della connessione
  double? mbps;
  DateTime? _mbpsAt;

  bool get loggedIn => source != null;

  String _key(Map<String, dynamic> s) => jsonEncode(s);

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    favorites = (_prefs.getStringList('fav') ?? []).toSet();
    final r = _prefs.getString('recents');
    if (r != null) {
      recents = [for (final j in jsonDecode(r) as List) Item.fromJson(j as Map<String, dynamic>)];
    }
    Map<String, int> ints(String k) {
      final v = _prefs.getString(k);
      return v == null ? {} : (jsonDecode(v) as Map<String, dynamic>).map((a, b) => MapEntry(a, b as int));
    }

    positions = ints('pos');
    durations = ints('dur');
    final lc = _prefs.getString('lc');
    if (lc != null) {
      prefChannel = (jsonDecode(lc) as Map<String, dynamic>).map((k, v) => MapEntry(k, v as String));
    }
    previews = _prefs.getBool('previews') ?? !Device.lowEnd;
    heroSound = _prefs.getBool('heroSound') ?? false;
    slowWarn = _prefs.getBool('slowWarn') ?? true;
    posterSecs = _prefs.getInt('posterSecs') ?? 5;
    heroMode = _prefs.getInt('heroMode') ?? 0;
    fitMode = _prefs.getInt('fitMode') ?? 0;
    bufferMode = _prefs.getInt('bufferMode') ?? (Device.lowEnd ? 0 : 1);
    uiSize = _prefs.getInt('uiSize') ?? 1;
    setUiFactor(_uiSizes[uiSize.clamp(0, 3)]);
    refreshHours = _prefs.getInt('refreshHours') ?? 6;
    heroIds = _prefs.getStringList('heroIds') ?? [];
    cacheTime = _prefs.getInt('cacheTime') ?? 0;

    final saved = _prefs.getString('source');
    if (saved != null) {
      source = jsonDecode(saved) as Map<String, dynamic>;
      final c = await loadCache(_key(source!)); // apertura immediata dalla copia locale
      if (c != null) {
        live = c.live;
        movies = c.movies;
        series = c.series;
        cacheTime = c.time;
        _indexLive();
      }
    }
    ready = true;
    notifyListeners();

    if (source != null) {
      final age = DateTime.now().millisecondsSinceEpoch - cacheTime;
      final stale = live.isEmpty || refreshHours == 0 || (refreshHours > 0 && age > refreshHours * 3600000);
      if (stale) {
        _load(source!);
      } else {
        _refreshMatches();
      }
    }
  }

  void _indexLive() => _liveById = {for (final c in live) c.id: c};

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

  Future<bool> _load(Map<String, dynamic> s) async {
    loading = true;
    error = null;
    refreshError = null;
    notifyListeners();
    try {
      List<Item> l, m, se;
      if (s['type'] == 'm3u') {
        final bytes = await fetchBytes(Uri.parse(s['url'] as String), idle: const Duration(seconds: 45));
        final all = await compute(_parseM3uBytes, bytes); // lettura fuori dal thread principale
        l = all.where((i) => i.kind == Kind.live).toList();
        m = all.where((i) => i.kind == Kind.movie).toList();
        se = all.where((i) => i.kind == Kind.series).toList();
      } else {
        final x = XtreamClient(s['server'] as String, s['user'] as String, s['pass'] as String);
        await x.checkLogin();
        Object? firstErr;
        Future<List<Item>> safe(Future<List<Item>> Function() f) async {
          try {
            return await f();
          } catch (e) {
            firstErr ??= e;
            return <Item>[];
          }
        }

        final r = await Future.wait([safe(x.live), safe(x.movies), safe(x.series)]);
        l = r[0];
        m = r[1];
        se = r[2];
        if (l.isEmpty && m.isEmpty && se.isEmpty && firstErr != null) throw firstErr!;
      }
      if (l.isEmpty && m.isEmpty && se.isEmpty) throw const NetError('La playlist è vuota o non valida.');
      live = l;
      movies = m;
      series = se;
      _indexLive();
      cacheTime = DateTime.now().millisecondsSinceEpoch;
      _prefs.setInt('cacheTime', cacheTime);
      loading = false;
      notifyListeners();
      saveCache(_key(s), l, m, se);
      _refreshMatches();
      return true;
    } catch (e) {
      final msg = explain(e);
      if (live.isEmpty && movies.isEmpty && series.isEmpty) {
        error = msg;
      } else {
        refreshError = msg; // restano i dati salvati
      }
      loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _prefs.remove('source');
    await deleteCache();
    source = null;
    live = [];
    movies = [];
    series = [];
    _indexLive();
    error = null;
    refreshError = null;
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

  // ---- anteprime e scheda attiva ----
  bool heroActiveFor(int t) => tab == t && _routes == 0;

  void setTab(int i) {
    if (i != tab) {
      tab = i;
      notifyListeners();
    }
  }

  void routePush() {
    _routes++;
    notifyListeners();
  }

  void routePop() {
    _routes--;
    notifyListeners();
  }

  // ---- canali per le partite ----
  bool hasPreferred(Fixture m) => _preferred(m) != null;

  Item? _preferred(Fixture m) {
    final id = prefChannel[m.tag];
    return id == null ? null : _liveById[id];
  }

  Item? bestChannel(Fixture m) {
    final p = _preferred(m);
    if (p != null) return p;
    final l = sportsChannels(live, m.tag);
    return l.isEmpty ? null : l.first;
  }

  void setPreferred(Fixture m, Item c) {
    prefChannel[m.tag] = c.id;
    _prefs.setString('lc', jsonEncode(prefChannel));
  }

  void _refreshMatches() {
    fetchMatches().then((m) {
      matches = m;
      notifyListeners();
    });
  }

  // ---- cronologia ----
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
      durations.remove(url);
    } else if (sec > 10) {
      positions[url] = sec;
      if (total > 0) durations[url] = total;
    }
    _prefs.setString('pos', jsonEncode(positions));
    _prefs.setString('dur', jsonEncode(durations));
  }

  double? progressOf(String url) {
    final p = positions[url];
    final d = durations[url];
    if (p == null || d == null || d <= 0) return null;
    return (p / d).clamp(0.0, 1.0).toDouble();
  }

  void clearHistory() {
    recents = [];
    positions = {};
    durations = {};
    _prefs.remove('recents');
    _prefs.remove('pos');
    _prefs.remove('dur');
    notifyListeners();
  }

  Future<void> clearPlaylistCache() async {
    await deleteCache();
    cacheTime = 0;
    _prefs.setInt('cacheTime', 0);
    notifyListeners();
  }

  // ---- qualità e connessione ----
  /// Versione dello stesso canale con risoluzione inferiore, se presente nella playlist.
  Item? lowerVariant(Item cur) {
    final key = baseKey(cur.name);
    if (key.isEmpty) return null;
    final cs = resolutionScore(cur.name);
    Item? best;
    var bs = -1;
    for (final c in live) {
      if (c.id == cur.id) continue;
      final sc = resolutionScore(c.name);
      if (sc >= cs || sc <= bs) continue;
      if (baseKey(c.name) != key) continue;
      best = c;
      bs = sc;
    }
    return best;
  }

  Future<double?> measureSpeed({bool force = false}) async {
    final at = _mbpsAt;
    if (!force && mbps != null && at != null && DateTime.now().difference(at) < const Duration(minutes: 5)) {
      return mbps;
    }
    final v = await speedTestMbps();
    if (v != null) {
      mbps = v;
      _mbpsAt = DateTime.now();
    }
    return v;
  }

  int get bufferMb => Device.lowEnd ? 32 : const [32, 96, 192][bufferMode.clamp(0, 2)];
  int get readaheadSecs => const [20, 40, 60][bufferMode.clamp(0, 2)];

  // ---- impostazioni ----
  List<Item> get heroChannels => [
        for (final id in heroIds)
          if (_liveById[id] != null) _liveById[id]!,
      ];

  void _setInt(String k, int v, void Function() apply) {
    apply();
    _prefs.setInt(k, v);
    notifyListeners();
  }

  void _setBool(String k, bool v, void Function() apply) {
    apply();
    _prefs.setBool(k, v);
    notifyListeners();
  }

  void setPreviews(bool v) => _setBool('previews', v, () => previews = v);
  void setHeroSound(bool v) => _setBool('heroSound', v, () => heroSound = v);
  void setSlowWarn(bool v) => _setBool('slowWarn', v, () => slowWarn = v);
  void setPosterSecs(int v) => _setInt('posterSecs', v, () => posterSecs = v);
  void setHeroMode(int v) => _setInt('heroMode', v, () => heroMode = v);
  void setFitMode(int v) => _setInt('fitMode', v, () => fitMode = v);
  void setBufferMode(int v) => _setInt('bufferMode', v, () => bufferMode = v);
  void setRefreshHours(int v) => _setInt('refreshHours', v, () => refreshHours = v);
  void setUiSize(int v) => _setInt('uiSize', v, () {
        uiSize = v;
        setUiFactor(_uiSizes[v.clamp(0, 3)]);
      });

  void setHeroIds(List<String> ids) {
    heroIds = ids;
    _prefs.setStringList('heroIds', ids);
    notifyListeners();
  }
}
