import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'app_state.dart';
import 'device.dart';
import 'epg.dart';
import 'models.dart';
import 'theme.dart';
import 'widgets.dart';

/// Zapping verticale: una sola connessione video attiva alla volta,
/// nessun pre-caricamento dei canali vicini, debounce sullo scroll.
/// Su Firestick (Device.isTv): cambio canale ISTANTANEO, niente animazione.
class ZappingScreen extends StatefulWidget {
  final AppState state;
  final int initialIndex;
  const ZappingScreen({super.key, required this.state, required this.initialIndex});

  @override
  State<ZappingScreen> createState() => _ZappingScreenState();
}

class _ZappingScreenState extends State<ZappingScreen> {
  late final PageController _page =
      PageController(initialPage: widget.initialIndex, viewportFraction: 1);
  late int _index = widget.initialIndex;
  late final Player _player = Player();
  late final VideoController _video = VideoController(_player);

  Timer? _debounce;
  String? _playingUrl;
  bool _opening = false;
  Epg? _epg;
  final _focus = FocusNode();

  List<Item> get _channels => widget.state.live;

  @override
  void initState() {
    super.initState();
    _player.setVolume(100);
    if (widget.state.live.isNotEmpty) {
      _schedule(widget.state.live[widget.initialIndex]);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _player.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _schedule(Item c) {
    _debounce?.cancel();
    _player.stop();
    _playingUrl = null;
    _opening = true;
    _epg = null;
    if (mounted) setState(() {});
    _debounce = Timer(const Duration(milliseconds: 400), () => _play(c));
  }

  Future<void> _play(Item c) async {
    if (!mounted) return;
    _playingUrl = c.url;
    await _player.open(Media(c.url));
    if (mounted) {
      setState(() => _opening = false);
      fetchEpg(c.url).then((e) {
        if (mounted && _channels[_index].url == c.url) {
          setState(() => _epg = e);
        }
      });
    }
  }

  /// Cambio pagina: istantaneo su TV, animato su touch.
  void _goTo(int i) {
    if (i < 0 || i >= _channels.length) return;
    if (Device.isTv) {
      _page.jumpToPage(i);
    } else {
      _page.animateToPage(i,
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  void _next() => _goTo(_index + 1);
  void _prev() => _goTo(_index - 1);

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (e.logicalKey == LogicalKeyboardKey.arrowDown) {
      _next();
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.arrowUp) {
      _prev();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final chs = _channels;
    if (chs.isEmpty) {
      return const Scaffold(body: Center(child: Text('Nessun canale disponibile.')));
    }
    final cur = chs[_index.clamp(0, chs.length - 1)];
    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: Stack(children: [
          PageView.builder(
            controller: _page,
            scrollDirection: Axis.vertical,
            // Su TV: nessuno scroll (solo D-pad). Su touch: scroll normale.
            physics: Device.isTv ? const NeverScrollableScrollPhysics() : null,
            itemCount: chs.length,
            onPageChanged: (i) {
              setState(() => _index = i);
              _schedule(chs[i]);
            },
            itemBuilder: (_, i) {
              final c = chs[i];
              final isCurrent = i == _index;
              return Stack(fit: StackFit.expand, children: [
                if (c.image != null)
                  Positioned.fill(
                    child: Image.network(
                      c.image!,
                      fit: BoxFit.cover,
                      color: Colors.black54,
                      colorBlendMode: BlendMode.darken,
                      cacheWidth: 1280,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                if (isCurrent && _playingUrl == c.url)
                  AnimatedOpacity(
                    opacity: 1,
                    duration: const Duration(milliseconds: 250),
                    child: Video(
                        controller: _video, controls: NoVideoControls, fit: BoxFit.contain),
                  )
                else if (isCurrent && _opening)
                  const Center(
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: CircularProgressIndicator(
                          strokeWidth: 3, color: AppColors.accent),
                    ),
                  ),
                if (!isCurrent)
                  Center(
                    child: SizedBox(
                      width: 220,
                      height: 124,
                      child: Art(url: c.image, title: c.name, contain: true),
                    ),
                  ),
                Positioned(
                  right: 20,
                  top: 60,
                  child: Text(
                    '${(i + 1).toString().padLeft(3, '0')}',
                    style: TextStyle(
                      fontSize: 120,
                      fontWeight: FontWeight.w900,
                      color: Colors.white.withAlpha(20),
                      height: 1,
                    ),
                  ),
                ),
                Positioned(
                  left: 20,
                  right: 60,
                  bottom: 40,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isCurrent) const LiveBadge(),
                      const SizedBox(height: 10),
                      Text(c.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.headlineMedium),
                      const SizedBox(height: 4),
                      Text(c.group, style: Theme.of(context).textTheme.bodySmall),
                      if (isCurrent && _epg?.now != null) ...[
                        const SizedBox(height: 14),
                        _EpgBlock(epg: _epg!),
                      ],
                    ],
                  ),
                ),
              ]);
            },
          ),
          Positioned(
            right: 12,
            top: 0,
            bottom: 0,
            child: SafeArea(
              child: Center(
                child: _ChannelMiniList(
                  channels: chs,
                  index: _index,
                  onSelect: _goTo,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(children: [
                BackButton(color: Colors.white, onPressed: () => Navigator.pop(context)),
                Expanded(
                  child: Text(cur.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                IconButton(
                  tooltip: widget.state.isFav(cur)
                      ? 'Rimuovi dai preferiti'
                      : 'Aggiungi ai preferiti',
                  onPressed: () => widget.state.toggleFav(cur),
                  icon: Icon(
                    widget.state.isFav(cur)
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: widget.state.isFav(cur) ? AppColors.accent : Colors.white,
                  ),
                  style: IconButton.styleFrom(backgroundColor: const Color(0x88000000)),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0x88000000),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${_index + 1}/${chs.length}',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _EpgBlock extends StatelessWidget {
  final Epg epg;
  const _EpgBlock({required this.epg});

  @override
  Widget build(BuildContext context) {
    final p = epg.now!;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisSize: MainAxisSize.min, children: [
        const Text('IN ONDA',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
                color: AppColors.accent)),
        const SizedBox(width: 8),
        Flexible(
          child: Text(p.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        ),
      ]),
      const SizedBox(height: 8),
      SizedBox(
        width: 240,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: p.progress,
            minHeight: 3,
            backgroundColor: Colors.white24,
            color: AppColors.accent,
          ),
        ),
      ),
    ]);
  }
}

class _ChannelMiniList extends StatelessWidget {
  final List<Item> channels;
  final int index;
  final ValueChanged<int> onSelect;
  const _ChannelMiniList({
    required this.channels,
    required this.index,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    const window = 5;
    final start = (index - 2).clamp(0, (channels.length - window).clamp(0, channels.length));
    final end = (start + window).clamp(0, channels.length);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = start; i < end; i++)
          GestureDetector(
            onTap: () => onSelect(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(vertical: 3),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: i == index ? AppColors.accent : const Color(0x66000000),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '${i + 1}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: i == index ? Colors.white : Colors.white70,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
