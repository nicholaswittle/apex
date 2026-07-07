import 'package:flutter/material.dart';

class WiSenseLoadingIndicator extends StatelessWidget {
  final double size;
  final Color? color;

  const WiSenseLoadingIndicator({
    super.key,
    this.size = 24,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: color ?? const Color(0xFFD97706),
      ),
    );
  }
}
