import 'package:flutter/material.dart';
import 'theme.dart';

class NavEntry {
  final String label;
  final IconData icon;
  const NavEntry(this.label, this.icon);
}

/// Barra flottante a pillola: la voce attiva si illumina di rosso
/// e mostra l'etichetta, con transizione animata.
class PremiumNav extends StatelessWidget {
  final List<NavEntry> entries;
  final int index;
  final ValueChanged<int> onChanged;
  final bool labelsAlways;

  const PremiumNav({
    super.key,
    required this.entries,
    required this.index,
    required this.onChanged,
    this.labelsAlways = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xE61B1B1F),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: const Color(0x1AFFFFFF)),
        boxShadow: const [
          BoxShadow(color: Color(0x73000000), blurRadius: 28, offset: Offset(0, 10)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < entries.length; i++)
            _NavButton(
              entry: entries[i],
              selected: i == index,
              showLabel: labelsAlways || i == index,
              onTap: () => onChanged(i),
            ),
        ],
      ),
    );
  }
}

class _NavButton extends StatefulWidget {
  final NavEntry entry;
  final bool selected;
  final bool showLabel;
  final VoidCallback onTap;
  const _NavButton({
    required this.entry,
    required this.selected,
    required this.showLabel,
    required this.onTap,
  });

  @override
  State<_NavButton> createState() => _NavButtonState();
}

class _NavButtonState extends State<_NavButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final sel = widget.selected;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: widget.onTap,
        onFocusChange: (v) => setState(() => _focused = v),
        borderRadius: BorderRadius.circular(30),
        focusColor: Colors.transparent,
        hoverColor: const Color(0x14FFFFFF),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(horizontal: widget.showLabel ? 20 : 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: sel
                ? const LinearGradient(colors: [Color(0xFFEF2B4D), AppColors.accentDark])
                : null,
            border: Border.all(
              color: _focused && !sel ? AppColors.accent : Colors.transparent,
              width: 2,
            ),
            boxShadow: sel
                ? const [BoxShadow(color: Color(0x66E5173F), blurRadius: 18, offset: Offset(0, 4))]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.entry.icon,
                  size: 22, color: sel ? Colors.white : AppColors.textSecondary),
              AnimatedSize(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                child: widget.showLabel
                    ? Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(
                          widget.entry.label,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: sel ? Colors.white : AppColors.textSecondary,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
