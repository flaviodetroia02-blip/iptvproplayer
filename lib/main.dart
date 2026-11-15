import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'app_state.dart';
import 'browse.dart';
import 'models.dart';
import 'premium_nav.dart';
import 'screens.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(const PlayerApp());
}

class PlayerApp extends StatefulWidget {
  const PlayerApp({super.key});

  @override
  State<PlayerApp> createState() => _PlayerAppState();
}

class _PlayerAppState extends State<PlayerApp> {
  final app = AppState();

  @override
  void initState() {
    super.initState();
    app.init();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Player',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          if (!app.ready) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator(color: AppColors.accent)));
          }
          return app.loggedIn ? Shell(state: app) : LoginScreen(state: app);
        },
      ),
    );
  }
}

class Shell extends StatefulWidget {
  final AppState state;
  const Shell({super.key, required this.state});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _index = 0;

  static const _entries = [
    NavEntry('TV', Icons.live_tv_rounded),
    NavEntry('Film', Icons.local_movies_rounded),
    NavEntry('Serie', Icons.video_library_rounded),
    NavEntry('Cerca', Icons.search_rounded),
  ];

  void _settings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.refresh_rounded),
            title: const Text('Aggiorna playlist'),
            onTap: () {
              Navigator.pop(ctx);
              widget.state.reload();
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout_rounded),
            title: const Text('Esci dal servizio'),
            onTap: () {
              Navigator.pop(ctx);
              widget.state.logout();
            },
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 14),
            child: Text('Versione 0.4',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final wide = MediaQuery.of(context).size.width >= 900;
    return Scaffold(
      body: Stack(children: [
        Padding(
          padding: EdgeInsets.only(top: wide ? 84 : 0, bottom: wide ? 0 : 96),
          child: IndexedStack(index: _index, children: [
            BrowseScreen(state: s, kind: Kind.live),
            BrowseScreen(state: s, kind: Kind.movie),
            BrowseScreen(state: s, kind: Kind.series),
            SearchScreen(state: s),
          ]),
        ),
        Align(
          alignment: wide ? Alignment.topCenter : Alignment.bottomCenter,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: PremiumNav(
                entries: _entries,
                index: _index,
                labelsAlways: wide,
                onChanged: (i) {
                  setState(() => _index = i);
                  s.setTab(i);
                },
              ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: IconButton(
                onPressed: _settings,
                icon: const Icon(Icons.tune_rounded),
                style: IconButton.styleFrom(backgroundColor: const Color(0x88000000)),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
