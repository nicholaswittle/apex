import 'package:flutter/material.dart';

class WiSenseLoadingIndicator extends StatelessWidget {
  const WiSenseLoadingIndicator({super.key, this.size = 24, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: size / 8,
        color: color,
      ),
    );
  }
}
