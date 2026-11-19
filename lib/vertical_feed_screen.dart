import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_state.dart';
import 'models.dart';
import 'screens.dart';
import 'theme.dart';
import 'widgets.dart';

/// Feed verticale per Film e Serie presenti nella lista caricata.
/// Parallasse fluida sull'immagine, indicatori in alto stile storie,
/// watchlist rapida e doppio gradiente per leggibilità.
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
  double _pageOffset = 0;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _page.addListener(() {
      final p = _page.page ?? 0;
      // Aggiorna solo se il cambiamento è significativo (efficienza su Firestick)
      if ((p - _pageOffset).abs() > 0.008) {
        setState(() => _pageOffset = p);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _page.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _next() {
    if (_index + 1 >= _items.length) return;
    _page.nextPage(duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic);
  }

  void _prev() {
    if (_index <= 0) return;
    _page.previousPage(duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic);
  }

  void _openTrailer(Item it) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(children: [
            Center(
              child: Image.network(
                'https://img.youtube.com/vi/${it.trailerId}/maxresdefault.jpg',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Art(url: it.image, title: it.name),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                style: IconButton.styleFrom(backgroundColor: const Color(0x88000000)),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
            Center(
              child: Icon(Icons.play_circle_filled_rounded,
                  size: 72, color: Colors.white.withAlpha(210)),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.transparent),
        body: const Center(child: Text('Nessun contenuto in lista.')),
      );
    }
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
        child: Stack(children: [
          PageView.builder(
            controller: _page,
            scrollDirection: Axis.vertical,
            itemCount: _items.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) {
              final it = _items[i];
              final delta = (i - _pageOffset).clamp(-1.0, 1.0);

              return Stack(fit: StackFit.expand, children: [
                // Parallasse: l'immagine si muove più lentamente dello scroll
                Transform.translate(
                  offset: Offset(0, delta * 90),
                  child: Transform.scale(
                    scale: 1 + (1 - delta.abs()) * 0.06,
                    child: it.trailerId != null
                        ? Image.network(
                            'https://img.youtube.com/vi/${it.trailerId}/maxresdefault.jpg',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                Art(url: it.image, title: it.name),
                          )
                        : Art(url: it.image, title: it.name),
                  ),
                ),

                // Doppio gradiente (alto + basso) per leggibilità
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

                // Barra indicatori in alto (stile storie)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 12,
                  left: 12,
                  right: 12,
                  child: Row(children: [
                    BackButton(color: Colors.white, onPressed: () => Navigator.pop(context)),
                    Expanded(
                      child: Row(children: [
                        for (var k = 0; k < _items.length; k++)
                          Expanded(
                            child: Container(
                              height: 2,
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              decoration: BoxDecoration(
                                color: k == _index ? Colors.white : Colors.white24,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                      ]),
                    ),
                    const SizedBox(width: 48),
                  ]),
                ),

                // Badge tipo
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

                // Info + azioni in basso
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
                          label: Text(
                              it.kind == Kind.series ? 'Guarda serie' : 'Guarda film'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 22, vertical: 14),
                          ),
                        ),
                        const SizedBox(width: 10),
                        if (it.trailerId != null)
                          SizedBox(
                            width: 52,
                            height: 52,
                            child: IconButton(
                              tooltip: 'Apri trailer',
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
          ),
        ]),
      ),
    );
  }
}
