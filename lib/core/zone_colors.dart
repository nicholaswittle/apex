import 'package:flutter/material.dart';

Color zoneColor(String zone) => switch (zone) {
      'Bar' => const Color(0xFF1D4ED8),
      'Kitchen' => const Color(0xFFD97706),
      'Floor' => const Color(0xFF059669),
      _ => Colors.grey,
    };
