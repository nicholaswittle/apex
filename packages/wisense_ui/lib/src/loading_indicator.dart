import 'package:flutter/material.dart';

class WiSenseLoadingIndicator extends StatelessWidget {
  const WiSenseLoadingIndicator({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) {
    return CircularProgressIndicator(color: color);
  }
}
