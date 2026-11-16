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
import 'screens.dart';
import 'theme.dart';

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
        await windowManager.setFullScreen(true); // su PC si apre a schermo intero
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
          // F11 attiva/disattiva lo schermo intero, Esc lo chiude (solo su PC)
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
          StatefulBuilder(
            builder: (c, setS) => SwitchListTile(
              secondary: const Icon(Icons.play_circle_outline_rounded),
              title: const Text('Anteprime video'),
              subtitle: const Text('Disattivale se l\'app è lenta'),
              value: widget.state.previews,
              activeColor: AppColors.accent,
              onChanged: (v) {
                widget.state.setPreviews(v);
                setS(() {});
              },
            ),
          ),
          if (_desktop)
            ListTile(
              leading: const Icon(Icons.fullscreen_rounded),
              title: const Text('Schermo intero (F11)'),
              onTap: () {
                Navigator.pop(ctx);
                toggleFullScreen();
              },
            ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 14),
            child: Text('Versione 0.6${kBuild > 0 ? ' (build $kBuild)' : ''}',
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
