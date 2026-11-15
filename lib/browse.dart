import 'package:flutter/material.dart';
import 'app_state.dart';
import 'hero_carousel.dart';
import 'models.dart';
import 'screens.dart';
import 'sports.dart';
import 'theme.dart';
import 'widgets.dart';

/// Sezione TV (stile DAZN) oppure Film / Serie (stile Netflix).
class BrowseScreen extends StatefulWidget {
  final AppState state;
  final Kind kind;
  const BrowseScreen({super.key, required this.state, required this.kind});

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> {
  String? _group;
  int _day = 0;
  List<Item> _newest = [];
  List<Item>? _memoFor;
  Map<String, List<Item>> _memo = {};

  AppState get state => widget.state;
  Kind get kind => widget.kind;

  /// Categorie con tutti i loro titoli. Per film e serie, "Netflix" va per prima.
  Map<String, List<Item>> _groups(List<Item> items) {
    if (identical(items, _memoFor)) return _memo;
    final g = <String, List<Item>>{};
    for (final i in items) {
      (g[i.group] ??= []).add(i);
    }
    var names = g.keys.toList();
    if (kind != Kind.live) {
      bool isN(String s) => s.toLowerCase().contains('netflix');
      names = [...names.where(isN), ...names.where((s) => !isN(s))];
    }
    _newest = (items.where((i) => i.added != null).toList()..sort((a, b) => b.added!.compareTo(a.added!)))
        .take(20)
        .toList();
    _memoFor = items;
    return _memo = {for (final n in names) n: g[n]!};
  }

  List<HeroSlide> _vodSlides(BuildContext context) {
    final withImg = state.itemsOf(kind).where((i) => i.image != null).toList();
    // In primo piano solo la categoria Netflix; se non esiste, le novità in generale.
    var pool = withImg.where((i) => i.group.toLowerCase().contains('netflix')).toList();
    if (pool.isEmpty) pool = withImg;
    pool.sort((a, b) => (b.added ?? 0).compareTo(a.added ?? 0));
    return [
      for (final i in pool.take(8))
        HeroSlide(
          id: i.id,
          badge: i.kind == Kind.movie ? 'Film' : 'Serie TV',
          title: i.name,
          subtitle: i.group,
          live: false,
          image: i.image,
          preview: i.url.isEmpty ? null : i,
          previewLoader: i.url.isEmpty
              ? () async {
                  final eps = await state.episodes(i);
                  return eps.isEmpty ? null : eps.first.url;
                }
              : null,
          onWatch: () => openItem(context, state, i),
          onChange: () => showInfo(context, state, i),
        ),
    ];
  }

  List<HeroSlide> _slides(BuildContext context) {
    if (kind != Kind.live) return _vodSlides(context);
    final out = <HeroSlide>[];
    for (final m in state.matches.take(8)) {
      final best = state.bestChannel(m);
      out.add(HeroSlide(
        id: '${m.home}-${m.away}',
        badge: m.league,
        title: '${m.home} – ${m.away}',
        subtitle: m.when,
        live: m.live,
        preview: best,
        onWatch: () => (best != null && state.hasPreferred(m))
            ? openItem(context, state, best)
            : showChannelPicker(context, state, m),
        onChange: () => showChannelPicker(context, state, m),
        poster: (ctx) => EventPoster(match: m),
      ));
    }
    if (out.isEmpty) {
      for (final c in popularChannels(state.live).take(6)) {
        out.add(HeroSlide(
          id: c.id,
          badge: 'Tra i più seguiti in Italia',
          title: c.name,
          subtitle: c.group,
          live: false,
          preview: c,
          onWatch: () => openItem(context, state, c),
        ));
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) => ColoredBox(
        color: kind == Kind.live ? AppColors.background : Colors.black,
        child: _body(context),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final items = state.itemsOf(kind);
    if (items.isEmpty) {
      return Center(
        child: state.loading
            ? const CircularProgressIndicator(color: AppColors.accent)
            : Padding(
                padding: const EdgeInsets.all(32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(state.error ?? 'Nessun contenuto in questa sezione.',
                      textAlign: TextAlign.center),
                  if (state.error != null) ...[
                    const SizedBox(height: 16),
                    FilledButton(onPressed: () => state.reload(), child: const Text('Riprova')),
                  ],
                ]),
              ),
      );
    }

    final live = kind == Kind.live;
    final groups = _groups(items);
    if (_group != null && !groups.containsKey(_group)) _group = null;
    final favs = live ? state.favoriteLive : <Item>[];
    final recents = state.recents.where((i) => i.kind == kind).toList();
    final h = live ? 224.0 : 262.0;

    Widget card(Item i) => live
        ? LiveCard(
            item: i,
            fav: state.isFav(i),
            onTap: () => openItem(context, state, i),
            onLong: () => state.toggleFav(i))
        : PosterCard(
            item: i,
            progress: state.progressOf(i.url),
            onTap: () => openItem(context, state, i));

    final featured = favs.isNotEmpty
        ? favs.first
        : items.firstWhere((i) => i.image != null, orElse: () => items.first);
    Widget hero = FeaturedBanner(
      item: featured,
      cover: !live,
      fav: state.isFav(featured),
      playLabel: kind == Kind.series ? 'Guarda' : 'Guarda ora',
      onPlay: () => openItem(context, state, featured),
      onFav: () => state.toggleFav(featured),
    );
    final slides = _slides(context);
    if (slides.isNotEmpty) {
      hero = HeroCarousel(slides: slides, active: state.heroActiveFor(kind.index), netflix: !live);
    }

    final slivers = <Widget>[SliverToBoxAdapter(child: hero)];

    if (live && state.matches.isNotEmpty) {
      final byDay = <DateTime, List<Fixture>>{};
      for (final m in state.matches) {
        (byDay[DateTime(m.start.year, m.start.month, m.start.day)] ??= []).add(m);
      }
      final days = byDay.keys.toList()..sort();
      final day = _day.clamp(0, days.length - 1);
      final today = DateTime.now();
      String label(DateTime d) {
        final diff = d.difference(DateTime(today.year, today.month, today.day)).inDays;
        if (diff <= 0) return 'Oggi';
        if (diff == 1) return 'Domani';
        const n = ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'];
        return '${n[d.weekday - 1]} ${d.day}';
      }
      final list = byDay[days[day]]!;
      list.sort((a, b) => a.start.compareTo(b.start));
      slivers.add(SliverToBoxAdapter(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 10),
            child: Text('Calendario calcio', style: Theme.of(context).textTheme.titleMedium),
          ),
          DayTabs(
            labels: [for (final d in days) label(d)],
            selected: day,
            onSelect: (i) => setState(() => _day = i),
          ),
          Rail(
            title: '',
            height: 250,
            children: [
              for (final m in list)
                MatchCard(match: m, onWatch: () => showChannelPicker(context, state, m)),
            ],
          ),
        ]),
      ));
    }
    if (live) {
      slivers.add(SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 22),
          child: GenreChips(
            groups: groups.keys.toList(),
            selected: _group,
            onSelect: (g) => setState(() => _group = g),
          ),
        ),
      ));
    }

    if (_group != null) {
      final list = groups[_group]!;
      if (!live) {
        slivers.add(SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 16, 24, 0),
            child: Row(children: [
              IconButton(
                onPressed: () => setState(() => _group = null),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              Expanded(
                child: Text(_group!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium),
              ),
            ]),
          ),
        ));
      }
      slivers.add(SliverPadding(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
        sliver: SliverGrid(
          gridDelegate: live
              ? const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 290,
                  mainAxisExtent: 200,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16)
              : const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 166,
                  mainAxisExtent: 238,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16),
          delegate: SliverChildBuilderDelegate(
            (c, i) => Align(alignment: Alignment.topLeft, child: card(list[i])),
            childCount: list.length,
          ),
        ),
      ));
    } else {
      final rails = <Widget>[];
      if (recents.isNotEmpty) {
        rails.add(Rail(
          title: live ? 'Visti di recente' : 'Continua a guardare',
          height: h,
          children: [for (final i in recents) card(i)],
        ));
      }
      if (favs.isNotEmpty) {
        rails.add(Rail(title: 'Preferiti', height: h, children: [for (final i in favs) card(i)]));
      }
      if (!live && _newest.isNotEmpty) {
        rails.add(Rail(
            title: 'Aggiunti di recente',
            height: h,
            children: [for (final i in _newest) card(i)]));
      }
      for (final e in groups.entries) {
        rails.add(Rail(
          title: e.key,
          height: h,
          onSeeAll: () => setState(() => _group = e.key),
          children: [for (final i in (live ? e.value : e.value.take(40))) card(i)],
        ));
      }
      slivers.add(SliverList(delegate: SliverChildListDelegate(rails)));
    }

    slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 40)));
    return CustomScrollView(slivers: slivers);
  }
}
