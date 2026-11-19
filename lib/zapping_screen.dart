import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'app_state.dart';
import 'models.dart';
import 'theme.dart';
import 'widgets.dart';

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
    _debounce = Timer(const Duration(milliseconds: 400), () => _play(c));
  }

  Future<void> _play(Item c) async {
    if (!mounted) return;
    _playingUrl = c.url;
    await _player.open(Media(c.url));
    if (mounted) setState(() {});
  }

  void _next() {
    if (_index + 1 >= _channels.length) return;
    _page.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  void _prev() {
    if (_index <= 0) return;
    _page.previousPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

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
            itemCount: chs.length,
            onPageChanged: (i) {
              setState(() => _index = i);
              _schedule(chs[i]);
            },
            itemBuilder: (_, i) {
              final c = chs[i];
              final isCurrent = i == _index;
              return Stack(fit: StackFit.expand, children: [
                if (isCurrent && _playingUrl == c.url)
                  Video(controller: _video, controls: NoVideoControls, fit: BoxFit.contain)
                else
                  const ColoredBox(color: Colors.black),
                if (!(isCurrent && _playingUrl == c.url))
                  Center(
                    child: SizedBox(
                      width: 220,
                      height: 124,
                      child: Art(url: c.image, title: c.name, contain: true),
                    ),
                  ),
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 40,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (isCurrent) const LiveBadge(),
                    const SizedBox(height: 10),
                    Text(c.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 4),
                    Text(c.group, style: Theme.of(context).textTheme.bodySmall),
                  ]),
                ),
              ]);
            },
          ),
          SafeArea(
            child: Row(children: [
              BackButton(color: Colors.white, onPressed: () => Navigator.pop(context)),
              Expanded(
                child: Text(chs[_index.clamp(0, chs.length - 1)].name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text('${_index + 1}/${chs.length}',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
