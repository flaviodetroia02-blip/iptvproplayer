import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_state.dart';
import 'device.dart';
import 'models.dart';
import 'screens.dart';
import 'theme.dart';
import 'widgets.dart';

class VerticalFeedScreen extends StatefulWidget {
  final AppState state;
  final Kind kind;
  const VerticalFeedScreen({super.key, required this.state, required this.kind});

  @override
  State<VerticalFeedScreen> createState() => _VerticalFeedScreenState();
}

class _VerticalFeedScreenState extends State<VerticalFeedScreen> {
  late final List<Item> _items = widget.state.itemsOf(widget.kind);
  final _focus = FocusNode();
  final _page = PageController();
  int _index = 0;

  @override
  void initState() {
    super.initState();
    if (Device.isTv) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
    }
  }

  @override
  void dispose() {
    _page.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _goTo(int i) {
    if (i < 0 || i >= _items.length) return;
    if (Device.isTv) {
      _page.jumpToPage(i);
    } else {
      _page.animateToPage(i,
          duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic);
    }
  }

  void _next() => _goTo(_index + 1);
  void _prev() => _goTo(_index - 1);

  Future<void> _openTrailer(Item it) async {
    final url = Uri.parse('https://www.youtube.com/watch?v=${it.trailerId}');
    try {
      final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossibile aprire YouTube')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossibile aprire YouTube')),
        );
      }
    }
  }

  /// Barra indicatori LIMITATA a 15 tacche attorno all'indice corrente.
  /// Prima creava un widget per ogni item (5000 serie = blocco totale).
  Widget _indicators(int total, int current) {
    const maxVisible = 15;
    final start = (current - maxVisible ~/ 2).clamp(0, (total - maxVisible).clamp(0, total));
    final end = (start + maxVisible).clamp(0, total);
    return Row(
      children: [
        for (var k = start; k < end; k++)
          Expanded(
            child: Container(
              height: 2,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: k == current ? Colors.white : Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.transparent),
        child: const Center(child: Text('Nessun contenuto in lista.')),
      );
    }
    final isTv = Device.isTv;

    final pageView = PageView.builder(
      controller: _page,
      scrollDirection: Axis.vertical,
      physics: isTv ? const NeverScrollableScrollPhysics() : null,
      itemCount: _items.length,
      onPageChanged: (i) => setState(() => _index = i),
      itemBuilder: (_, i) {
        final it = _items[i];

        return Stack(fit: StackFit.expand, children: [
          Art(url: it.image, title: it.name),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xBB000000),
                  Color(0x00000000),
                  Color(0x00000000),
                  Color(0xE0000000),
                ],
                stops: [0, 0.25, 0.55, 1],
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 12,
            right: 12,
            child: Row(children: [
              BackButton(color: Colors.white, onPressed: () => Navigator.pop(context)),
              Expanded(child: _indicators(_items.length, _index)),
              const SizedBox(width: 48),
            ]),
          ),
          Positioned(
            left: 20,
            bottom: 240,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                it.kind == Kind.movie ? 'FILM' : 'SERIE TV',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 2),
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 40,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(it.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(fontSize: 30)),
                const SizedBox(height: 4),
                Text(it.group, style: Theme.of(context).textTheme.bodySmall),
                if (it.trailerId != null) ...[
                  const SizedBox(height: 4),
                  const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.play_circle_outline_rounded,
                        size: 14, color: AppColors.textSecondary),
                    SizedBox(width: 4),
                    Text('Trailer disponibile',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ]),
                ],
                const SizedBox(height: 18),
                Row(children: [
                  FilledButton.icon(
                    onPressed: () => openItem(context, widget.state, it),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(it.kind == Kind.series ? 'Guarda serie' : 'Guarda film'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (it.trailerId != null)
                    SizedBox(
                      width: 52,
                      height: 52,
                      child: IconButton(
                        tooltip: 'Guarda il trailer su YouTube',
                        onPressed: () => _openTrailer(it),
                        icon: const Icon(Icons.play_circle_outline_rounded),
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0x33FFFFFF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 52,
                    height: 52,
                    child: IconButton(
                      tooltip: 'Aggiungi alla lista',
                      onPressed: () {
                        widget.state.toggleFav(it);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              widget.state.isFav(it)
                                  ? 'Aggiunto alla lista'
                                  : 'Rimosso dalla lista',
                              style: const TextStyle(color: Colors.white),
                            ),
                            duration: const Duration(milliseconds: 1200),
                            backgroundColor: AppColors.surfaceHigh,
                          ),
                        );
                      },
                      icon: Icon(
                        widget.state.isFav(it)
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        color: widget.state.isFav(it)
                            ? AppColors.accent
                            : Colors.white,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0x33FFFFFF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ]);
      },
    );

    // Solo su TV avvolgo nel Focus (Android non ne ha bisogno e il Focus
    // intercettava i tocchi, bloccando di fatto il PageView).
    if (isTv) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Focus(
          focusNode: _focus,
          autofocus: true,
          onKeyEvent: (node, e) {
            if (e is KeyDownEvent || e is KeyRepeatEvent) {
              if (e.logicalKey == LogicalKeyboardKey.arrowDown) {
                _next();
                return KeyEventResult.handled;
              }
              if (e.logicalKey == LogicalKeyboardKey.arrowUp) {
                _prev();
                return KeyEventResult.handled;
              }
            }
            return KeyEventResult.ignored;
          },
          child: pageView,
        ),
      );
    }

    return Scaffold(backgroundColor: Colors.black, body: pageView);
  }
}
