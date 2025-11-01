import 'package:flutter/material.dart';

/// Simple global theme notifier to switch between light and dark modes.
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);
