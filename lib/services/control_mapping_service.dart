import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CustomButton {
  final String id;
  final String label;
  final String code;
  final String behavior; // 'tap' (send once on press) or 'hold' (send on down, send release on up)

  CustomButton({
    required this.id,
    required this.label,
    required this.code,
    required this.behavior,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'code': code,
        'behavior': behavior,
      };

  factory CustomButton.fromJson(Map<String, dynamic> json) => CustomButton(
        id: json['id'] ?? '',
        label: json['label'] ?? '',
        code: json['code'] ?? '',
        behavior: json['behavior'] ?? 'tap',
      );
}

class ControlMappingService extends ChangeNotifier {
  static final ControlMappingService _instance = ControlMappingService._internal();
  factory ControlMappingService() => _instance;
  ControlMappingService._internal();

  late SharedPreferences _prefs;
  bool _isInitialized = false;

  // Default standard key mappings
  final Map<String, String> _defaultMappings = {
    'maju': 'w',
    'mundur': 'z',
    'kiri': 'a',
    'kanan': 's',
    'putar_kiri': 'd',
    'putar_kanan': 'k',
    'kepala_kiri': 'f',
    'kepala_kanan': 'j',
    'kepala_tengah': 'e',
    'stop': 'x',
  };

  Map<String, String> _mappings = {};
  List<CustomButton> _customButtons = [];
  bool _hapticFeedbackEnabled = true;

  Map<String, String> get mappings => _mappings;
  List<CustomButton> get customButtons => _customButtons;
  bool get hapticFeedbackEnabled => _hapticFeedbackEnabled;

  Future<void> init() async {
    if (_isInitialized) return;
    _prefs = await SharedPreferences.getInstance();

    // Load mappings
    _mappings = Map<String, String>.from(_defaultMappings);
    for (String key in _defaultMappings.keys) {
      final savedValue = _prefs.getString('map_$key');
      if (savedValue != null) {
        _mappings[key] = savedValue;
      }
    }

    // Load custom buttons
    final customButtonsJson = _prefs.getString('custom_buttons');
    if (customButtonsJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(customButtonsJson);
        _customButtons = decoded.map((item) => CustomButton.fromJson(item)).toList();
      } catch (e) {
        _customButtons = [];
      }
    } else {
      // Add default custom buttons as examples
      _customButtons = [
        CustomButton(id: 'btn_1', label: 'LED ON', code: '1', behavior: 'tap'),
        CustomButton(id: 'btn_2', label: 'LED OFF', code: '0', behavior: 'tap'),
        CustomButton(id: 'btn_3', label: 'STAND UP', code: 'u', behavior: 'tap'),
      ];
      await _saveCustomButtons();
    }

    // Load other settings
    _hapticFeedbackEnabled = _prefs.getBool('haptic_feedback') ?? true;

    _isInitialized = true;
    notifyListeners();
  }

  Future<void> updateMapping(String key, String value) async {
    if (value.isEmpty) return;
    _mappings[key] = value;
    await _prefs.setString('map_$key', value);
    notifyListeners();
  }

  Future<void> resetMappings() async {
    _mappings = Map<String, String>.from(_defaultMappings);
    for (String key in _defaultMappings.keys) {
      await _prefs.remove('map_$key');
    }
    notifyListeners();
  }

  Future<void> addCustomButton(String label, String code, String behavior) async {
    final newBtn = CustomButton(
      id: 'btn_${DateTime.now().millisecondsSinceEpoch}',
      label: label,
      code: code,
      behavior: behavior,
    );
    _customButtons.add(newBtn);
    await _saveCustomButtons();
    notifyListeners();
  }

  Future<void> deleteCustomButton(String id) async {
    _customButtons.removeWhere((btn) => btn.id == id);
    await _saveCustomButtons();
    notifyListeners();
  }

  Future<void> updateCustomButton(String id, String label, String code, String behavior) async {
    final index = _customButtons.indexWhere((btn) => btn.id == id);
    if (index != -1) {
      _customButtons[index] = CustomButton(id: id, label: label, code: code, behavior: behavior);
      await _saveCustomButtons();
      notifyListeners();
    }
  }

  Future<void> setHapticFeedback(bool enabled) async {
    _hapticFeedbackEnabled = enabled;
    await _prefs.setBool('haptic_feedback', enabled);
    notifyListeners();
  }

  Future<void> _saveCustomButtons() async {
    final encoded = jsonEncode(_customButtons.map((btn) => btn.toJson()).toList());
    await _prefs.setString('custom_buttons', encoded);
  }
}
