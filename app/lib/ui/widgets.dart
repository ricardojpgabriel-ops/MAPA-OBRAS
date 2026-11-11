import 'package:flutter/material.dart';
import 'theme.dart';

/// Bola de número/estrela, com estado de acerto.
class Ball extends StatelessWidget {
  final String value;
  final bool star;
  final bool hit;
  final bool miss;
  final double size;
  const Ball(this.value,
      {super.key, this.star = false, this.hit = false, this.miss = false, this.size = 38});

  @override
  Widget build(BuildContext context) {
    final base = star ? santaGold : Colors.white;
    final border = star ? const Color(0xFFc98f00) : santaGreen;
    Color bg = base, fg = star ? const Color(0xFF3A2C00) : santaGreen;
    if (hit) {
      bg = star ? const Color(0xFFc98f00) : santaGreen;
      fg = Colors.white;
    }
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: border, width: 2),
        boxShadow: hit
            ? [BoxShadow(color: border.withOpacity(.5), blurRadius: 8, spreadRadius: 1)]
            : null,
      ),
      child: Opacity(
        opacity: miss ? 0.38 : 1,
        child: Text(value,
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: size * 0.4, color: fg)),
      ),
    );
  }
}

/// Cabeçalho de secção.
class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text.toUpperCase(),
            style: const TextStyle(
                fontSize: 12,
                letterSpacing: 0.6,
                fontWeight: FontWeight.w800,
                color: Color(0xFF6B7280))),
      );
}
