import 'package:flutter/material.dart';
import 'app_state.dart';
import 'models.dart';
import 'player_screen.dart';
import 'theme.dart';
import 'widgets.dart';

void openItem(BuildContext context, AppState state, Item i) {
  final Widget page = (i.kind == Kind.series && i.url.isEmpty)
      ? SeriesDetail(state: state, item: i)
      : PlayerScreen(title: i.name, url: i.url);
  Navigator.push(context, MaterialPageRoute(builder: (_) => page));
}

/// Pagina di una sezione: TV diretta (schede 16:9) oppure film/serie (locandine).
class BrowseScreen extends StatelessWidget {
  final AppState state;
  final Kind kind;
  const BrowseScreen({super.key, required this.state, required this.kind});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(listenable: state, builder: (c, _) => _body(c));
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
    final favs = live ? state.favoriteLive : <Item>[];
    final featured = favs.isNotEmpty
        ? favs.first
        : items.firstWhere((i) => i.image != null, orElse: () => items.first);
    final h = live ? 224.0 : 284.0;
    Widget card(Item i) => live
        ? LiveCard(
            item: i,
            fav: state.isFav(i),
            onTap: () => openItem(context, state, i),
            onLong: () => state.toggleFav(i))
        : PosterCard(item: i, onTap: () => openItem(context, state, i));

    return ListView(padding: const EdgeInsets.only(bottom: 32), children: [
      FeaturedBanner(
        item: featured,
        cover: !live,
        fav: state.isFav(featured),
        playLabel: kind == Kind.series ? 'Guarda' : 'Guarda ora',
        onPlay: () => openItem(context, state, featured),
        onFav: () => state.toggleFav(featured),
      ),
      if (favs.isNotEmpty) Rail(title: 'Preferiti', height: h, children: [for (final i in favs) card(i)]),
      for (final e in state.grouped(items).entries)
        Rail(title: e.key, height: h, children: [for (final i in e.value) card(i)]),
    ]);
  }
}

class SearchScreen extends StatefulWidget {
  final AppState state;
  const SearchScreen({super.key, required this.state});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String q = '';

  String _label(Kind k) => k == Kind.live ? 'Canale' : (k == Kind.movie ? 'Film' : 'Serie');

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final matches = q.length < 2
        ? <Item>[]
        : [...s.live, ...s.movies, ...s.series]
            .where((i) => i.name.toLowerCase().contains(q))
            .take(60)
            .toList();
    return SafeArea(
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: TextField(
            onChanged: (v) => setState(() => q = v.trim().toLowerCase()),
            decoration: const InputDecoration(
              hintText: 'Cerca canali, film e serie',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
        ),
        Expanded(
          child: q.length < 2
              ? Center(
                  child: Text('Scrivi almeno due lettere.',
                      style: Theme.of(context).textTheme.bodySmall))
              : matches.isEmpty
                  ? Center(
                      child: Text('Nessun risultato.', style: Theme.of(context).textTheme.bodySmall))
                  : ListView.builder(
                      itemCount: matches.length,
                      itemBuilder: (_, i) {
                        final it = matches[i];
                        return ListTile(
                          leading: SizedBox(
                            width: 56,
                            height: 56,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Art(url: it.image, title: it.name, contain: it.kind == Kind.live),
                            ),
                          ),
                          title: Text(it.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text('${_label(it.kind)}, ${it.group}',
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          onTap: () => openItem(context, s, it),
                        );
                      },
                    ),
        ),
      ]),
    );
  }
}

class SeriesDetail extends StatelessWidget {
  final AppState state;
  final Item item;
  const SeriesDetail({super.key, required this.state, required this.item});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(item.name), backgroundColor: Colors.transparent),
      body: FutureBuilder<List<Episode>>(
        future: state.episodes(item),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(color: AppColors.accent));
          }
          final eps = snap.data ?? [];
          if (snap.hasError || eps.isEmpty) {
            return const Center(child: Text('Episodi non disponibili.'));
          }
          final seasons = <int, List<Episode>>{};
          for (final e in eps) {
            (seasons[e.season] ??= []).add(e);
          }
          return ListView(children: [
            for (final s in seasons.entries) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
                child: Text('Stagione ${s.key}', style: Theme.of(context).textTheme.titleMedium),
              ),
              for (final e in s.value)
                ListTile(
                  leading: Text('${e.number}',
                      style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.accent)),
                  title: Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: const Icon(Icons.play_arrow_rounded),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => PlayerScreen(title: e.title, url: e.url)),
                  ),
                ),
            ],
          ]);
        },
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  final AppState state;
  const LoginScreen({super.key, required this.state});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool xtream = false;
  final url = TextEditingController();
  final server = TextEditingController();
  final user = TextEditingController();
  final pass = TextEditingController();

  Future<void> _submit() {
    final s = widget.state;
    return xtream
        ? s.connectXtream(server.text, user.text, pass.text)
        : s.connectM3u(url.text);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final s = widget.state;
        return Scaffold(
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.all(24),
                children: [
                  Text('Collega la tua playlist', style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 8),
                  Text('Inserisci il link M3U o i dati Xtream del tuo servizio.',
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 24),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('Link M3U')),
                      ButtonSegment(value: true, label: Text('Codice Xtream')),
                    ],
                    selected: {xtream},
                    onSelectionChanged: (v) => setState(() => xtream = v.first),
                  ),
                  const SizedBox(height: 20),
                  if (!xtream)
                    TextField(
                        controller: url,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(hintText: 'https://…/playlist.m3u'))
                  else ...[
                    TextField(
                        controller: server,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(hintText: 'Server (http://host:porta)')),
                    const SizedBox(height: 12),
                    TextField(controller: user, decoration: const InputDecoration(hintText: 'Utente')),
                    const SizedBox(height: 12),
                    TextField(
                        controller: pass,
                        obscureText: true,
                        decoration: const InputDecoration(hintText: 'Password')),
                  ],
                  if (s.error != null) ...[
                    const SizedBox(height: 14),
                    Text(s.error!, style: const TextStyle(color: AppColors.accent)),
                  ],
                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: s.loading ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: s.loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Carica'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
