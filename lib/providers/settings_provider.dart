import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kThemeModeKey = 'themeMode';

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kThemeModeKey);
    state = switch (raw) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeModeKey, mode.name);
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
  (ref) => ThemeModeNotifier(),
);

enum SortOrder { updatedDesc, createdDesc, titleAsc }

class SortOrderNotifier extends StateNotifier<SortOrder> {
  SortOrderNotifier() : super(SortOrder.updatedDesc) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('sortOrder');
    state = SortOrder.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => SortOrder.updatedDesc,
    );
  }

  Future<void> set(SortOrder order) async {
    state = order;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sortOrder', order.name);
  }
}

final sortOrderProvider = StateNotifierProvider<SortOrderNotifier, SortOrder>(
  (ref) => SortOrderNotifier(),
);
