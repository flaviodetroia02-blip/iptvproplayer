import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';
import 'app_state.dart';
import 'brand.dart';
import 'browse.dart';
import 'device.dart';
import 'updater.dart';
import 'models.dart';
import 'premium_nav.dart';
import 'resume_sheet.dart';
import 'settings_screen.dart';
import 'screens.dart';
import 'theme.dart';
import 'vertical_feed_screen.dart';
import 'zapping_screen.dart';

bool get _desktop => !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

Future<void> toggleFullScreen() async {
  if (!_desktop) return;
  await windowManager.setFullScreen(!(await windowManager.isFullScreen()));
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await Device.init();
  if (_desktop) {
    await windowManager.ensureInitialized();
    await windowManager.waitUntilReadyToShow(
      const WindowOptions(title: kAppName, backgroundColor: Colors.black),
      () async {
        await windowManager.setFullScreen(true);
        await windowManager.show();
        await windowManager.focus();
      },
    );
  }
  runApp(const PlayerApp());
}

class PlayerApp extends StatefulWidget {
  const PlayerApp({super.key});

  @override
  State<PlayerApp> createState() => _PlayerAppState();
}

class _PlayerAppState extends State<PlayerApp> {
  final app = AppState();
  bool _splash = true;

  @override
  void initState() {
    super.initState();
    app.init();
    Future.delayed(const Duration(milliseconds: 2600), () {
      if (mounted) setState(() => _splash = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: kAppName,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      builder: (context, child) => CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.f11): () => toggleFullScreen(),
          const SingleActivator(LogicalKeyboardKey.escape): () async {
            if (_desktop && await windowManager.isFullScreen()) {
              await windowManager.setFullScreen(false);
            }
          },
        },
        child: Focus(autofocus: true, child: child ?? const SizedBox.shrink()),
      ),
      home: ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          final Widget page = (_splash || !app.ready)
              ? const SplashScreen(key: ValueKey('splash'))
              : (app.loggedIn
                  ? Shell(key: const ValueKey('shell'), state: app)
                  : LoginScreen(key: const ValueKey('login'), state: app));
          return AnimatedSwitcher(duration: const Duration(milliseconds: 600), child: page);
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
    final s = widget.state;
    s.routePush();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsScreen(state: s, onFullScreen: _desktop ? toggleFullScreen : null),
      ),
    ).then((_) => s.routePop());
  }

  /// FAB grande "Scorri": zapping su TV, feed verticale su Film/Serie.
  void _quickScroll() {
    final s = widget.state;
    Widget? page;
    if (_index == 0 && s.live.isNotEmpty) {
      page = ZappingScreen(state: s, initialIndex: 0);
    } else if (_index == 1 && s.movies.isNotEmpty) {
      page = VerticalFeedScreen(state: s, kind: Kind.movie);
    } else if (_index == 2 && s.series.isNotEmpty) {
      page = VerticalFeedScreen(state: s, kind: Kind.series);
    }
    if (page == null) return;
    s.routePush();
    Navigator.push(context, MaterialPageRoute(builder: (_) => page!))
        .then((_) => s.routePop());
  }

  void _teamSheet() {
    final s = widget.state;
    const teams = [
      'Inter', 'Milan', 'Juventus', 'Napoli', 'Roma', 'Lazio',
      'Atalanta', 'Fiorentina', 'Bologna', 'Torino', 'Udinese', 'Genoa',
      'Cagliari', 'Lecce', 'Hellas Verona', 'Empoli', 'Parma', 'Como',
      'Monza', 'Venezia',
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Text('Notifiche partite', style: Theme.of(ctx).textTheme.titleMedium),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.flag_rounded),
                  title: const Text('Nazionale italiana'),
                  subtitle: const Text('Notifiche per gli Azzurri'),
                  value: s.nationalTeam,
                  activeColor: AppColors.accent,
                  onChanged: s.setNationalTeam,
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Text('Squadra del cuore',
                      style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                          color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
                ),
                Flexible(
                  child: ListView(shrinkWrap: true, children: [
                    ListTile(
                      leading: Icon(
                        s.favoriteTeam == null
                            ? Icons.check_circle_rounded
                            : Icons.circle_outlined,
                        color: s.favoriteTeam == null
                            ? AppColors.accent
                            : AppColors.textSecondary,
                      ),
                      title: const Text('Nessuna'),
                      onTap: () {
                        s.setFavoriteTeam(null);
                        Navigator.pop(ctx);
                      },
                    ),
                    for (final t in teams)
                      ListTile(
                        leading: Icon(
                          s.favoriteTeam == t
                              ? Icons.check_circle_rounded
                              : Icons.circle_outlined,
                          color: s.favoriteTeam == t
                              ? AppColors.accent
                              : AppColors.textSecondary,
                        ),
                        title: Text(t),
                        onTap: () {
                          s.setFavoriteTeam(t);
                          Navigator.pop(ctx);
                        },
                      ),
                  ]),
                ),
              ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final wide = MediaQuery.of(context).size.width >= 900;
    final showScrollFab = _index >= 0 && _index <= 2;
    final fabLabel = _index == 0 ? 'Zapping' : 'Feed';
    final fabIcon = _index == 0 ? Icons.swap_vert_rounded : Icons.swipe_vertical_rounded;

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
        // FAB grande "Scorri"/"Zapping" in basso a destra
        if (showScrollFab)
          Positioned(
            right: 16,
            bottom: wide ? 16 : 96,
            child: SafeArea(
              child: FloatingActionButton.extended(
                heroTag: 'scroll_fab',
                onPressed: _quickScroll,
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                icon: Icon(fabIcon, size: 24),
                label: Text(
                  fabLabel,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                tooltip: _index == 0
                    ? 'Zapping verticale canali'
                    : 'Scorri film e serie in verticale',
              ),
            ),
          ),
        Align(
          alignment: Alignment.topCenter,
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.only(top: wide ? 84 : 8, left: 16, right: 16),
              child: const UpdateBanner(),
            ),
          ),
        ),
        if (wide)
          const Positioned(
            top: 0,
            left: 0,
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(24, 22, 0, 0),
                child: BrandLogo(size: 17),
              ),
            ),
          ),
        // Barra in alto a destra: 3 pulsanti (riprendi, notifiche, impostazioni)
        Positioned(
          top: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                IconButton(
                  tooltip: 'Riprendi visione',
                  onPressed: () => showResumeSheet(context, s),
                  icon: const Icon(Icons.history_rounded),
                  style: IconButton.styleFrom(backgroundColor: const Color(0x88000000)),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Notifiche partite',
                  onPressed: _teamSheet,
                  icon: Icon(
                    s.favoriteTeam != null || s.nationalTeam
                        ? Icons.notifications_active_rounded
                        : Icons.notifications_none_rounded,
                  ),
                  style: IconButton.styleFrom(backgroundColor: const Color(0x88000000)),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _settings,
                  icon: const Icon(Icons.tune_rounded),
                  style: IconButton.styleFrom(backgroundColor: const Color(0x88000000)),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}
