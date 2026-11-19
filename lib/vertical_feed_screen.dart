import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_state.dart';
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
  late final PageController _page = PageController();
  int _index = 0;

  @override
  void initState() {
    super.initState();
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
    _page.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  void _prev() {
    if (_index <= 0) return;
    _page.previousPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
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
                  size: 72, color: Colors.white.withAlpha(200)),
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
              return Stack(fit: StackFit.expand, children: [
                if (it.trailerId != null)
                  Image.network(
                    'https://img.youtube.com/vi/${it.trailerId}/maxresdefault.jpg',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Art(url: it.image, title: it.name),
                  )
                else
                  Art(url: it.image, title: it.name),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x00000000), Color(0xDD000000)],
                      stops: [0.4, 1],
                    ),
                  ),
                ),
                Positioned(
                  left: 20,
                  top: MediaQuery.of(context).padding.top + 20,
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
                            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                          ),
                        ),
                        if (it.trailerId != null) ...[
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 52,
                            height: 52,
                            child: IconButton(
                              tooltip: 'Apri trailer',
                              onPressed: () => _openTrailer(it),
                              icon: const Icon(Icons.info_outline_rounded),
                              style: IconButton.styleFrom(
                                backgroundColor: const Color(0x33FFFFFF),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                          ),
                        ],
                      ]),
                    ],
                  ),
                ),
              ]);
            },
          ),
          SafeArea(
            child: Row(children: [
              BackButton(color: Colors.white, onPressed: () => Navigator.pop(context)),
              Expanded(
                child: Text(
                  widget.kind == Kind.movie ? 'Film' : 'Serie TV',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text('${_index + 1}/${_items.length}',
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
