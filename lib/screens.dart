import 'package:flutter/material.dart';
import 'app_state.dart';
import 'brand.dart';
import 'models.dart';
import 'player_screen.dart';
import 'sports.dart';
import 'theme.dart';
import 'widgets.dart';

void openItem(BuildContext context, AppState state, Item i) {
  final Widget page = (i.kind == Kind.series && i.url.isEmpty)
      ? SeriesDetail(state: state, item: i)
      : PlayerScreen(title: i.name, url: i.url, state: state, item: i);
  state.routePush();
  Navigator.push(context, MaterialPageRoute(builder: (_) => page)).then((_) => state.routePop());
}


/// Elenco dei canali sportivi della playlist per guardare una partita.
void showChannelPicker(BuildContext context, AppState state, Fixture m) {
  final list = sportsChannels(state.live, m.tag);
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${m.home} – ${m.away}', style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text('Scegli il canale: dipende dal tuo abbonamento.',
                  style: Theme.of(ctx).textTheme.bodySmall),
            ]),
          ),
          if (list.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Text('Nessun canale sportivo trovato nella tua playlist.'),
            )
          else
            Flexible(
              child: ListView(shrinkWrap: true, children: [
                for (final c in list)
                  ListTile(
                    leading: SizedBox(
                      width: 48,
                      height: 48,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Art(url: c.image, title: c.name, contain: true),
                      ),
                    ),
                    title: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: resolutionLabel(c.name).isEmpty
                        ? null
                        : Text(resolutionLabel(c.name),
                            style: const TextStyle(
                                color: AppColors.accent, fontWeight: FontWeight.w800, fontSize: 12.5)),
                    onTap: () {
                      Navigator.pop(ctx);
                      state.setPreferred(m, c);
                      openItem(context, state, c);
                    },
                  ),
              ]),
            ),
        ]),
      ),
    ),
  );
}

/// Scheda "Altre info" di un film (le serie aprono l'elenco degli episodi).
void showInfo(BuildContext context, AppState state, Item i) {
  if (i.kind == Kind.series) {
    openItem(context, state, i);
    return;
  }
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.surface,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 110,
            height: 165,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Art(url: i.image, title: i.name),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(i.name, style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(i.group, style: Theme.of(ctx).textTheme.bodySmall),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  openItem(context, state, i);
                },
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Riproduci'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                ),
              ),
            ]),
          ),
        ]),
      ),
    ),
  );
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

  Item _ep(Episode e) =>
      Item(name: e.title, url: e.url, group: item.name, kind: Kind.series, image: item.image);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
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
          return ListView(padding: EdgeInsets.zero, children: [
            SizedBox(
              height: 380,
              child: Stack(fit: StackFit.expand, children: [
                Art(url: item.image, title: item.name),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x66000000), Color(0x00000000), Colors.black],
                      stops: [0, 0.4, 1],
                    ),
                  ),
                ),
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: 24,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 6),
                    Text(item.group, style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => openItem(context, state, _ep(eps.first)),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Riproduci'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
                      ),
                    ),
                  ]),
                ),
              ]),
            ),
            for (final s in seasons.entries) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 6),
                child: Text('Stagione ${s.key}', style: Theme.of(context).textTheme.titleMedium),
              ),
              for (final e in s.value)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                  leading: Text('${e.number}',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                  title: Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: const Icon(Icons.play_circle_outline_rounded),
                  onTap: () => openItem(context, state, _ep(e)),
                ),
            ],
            const SizedBox(height: 32),
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
                  const BrandLogo(size: 30),
                  const SizedBox(height: 28),
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
