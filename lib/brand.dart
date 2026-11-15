import 'package:flutter/material.dart';
import 'theme.dart';

/// Logo: simbolo play su quadrato rosso e nome in nero pesante.
class BrandLogo extends StatelessWidget {
  final double size;
  const BrandLogo({super.key, this.size = 28});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: size * 1.25,
        height: size * 1.25,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFEF2B4D), AppColors.accentDark],
          ),
          borderRadius: BorderRadius.circular(size * 0.3),
          boxShadow: const [BoxShadow(color: Color(0x66E5173F), blurRadius: 24)],
        ),
        child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: size * 0.95),
      ),
      SizedBox(width: size * 0.4),
      Text(
        kAppName,
        style: TextStyle(
          fontSize: size * 1.15,
          fontWeight: FontWeight.w900,
          letterSpacing: size * 0.06,
          height: 1,
          color: Colors.white,
        ),
      ),
    ]);
  }
}

/// Schermata di apertura con il logo animato.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1900))..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(fit: StackFit.expand, children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.1),
              radius: 0.9,
              colors: [Color(0x33E5173F), Colors.black],
            ),
          ),
        ),
        Center(
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, __) {
              final a = Curves.easeOutCubic.transform((_c.value / 0.6).clamp(0.0, 1.0));
              final t = Curves.easeOut.transform(((_c.value - 0.45) / 0.4).clamp(0.0, 1.0));
              return Column(mainAxisSize: MainAxisSize.min, children: [
                Opacity(
                  opacity: a,
                  child: Transform.scale(scale: 0.88 + 0.12 * a, child: const BrandLogo(size: 44)),
                ),
                const SizedBox(height: 22),
                Opacity(
                  opacity: t,
                  child: Text(
                    kAppTagline.toUpperCase(),
                    style: const TextStyle(
                      letterSpacing: 5,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                Container(width: 120 * t, height: 2, color: AppColors.accent),
              ]);
            },
          ),
        ),
      ]),
    );
  }
}
