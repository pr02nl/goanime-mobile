import 'package:flutter/material.dart';

class LogoWidget extends StatelessWidget {
  final double size;
  final Color? color;

  const LogoWidget({super.key, this.size = 80, this.color});

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.play_circle_filled,
      size: size,
      color: color ?? Colors.white70,
      shadows: const [
        Shadow(offset: Offset(0, 1), blurRadius: 3.0, color: Colors.black26),
      ],
    );
  }
}
