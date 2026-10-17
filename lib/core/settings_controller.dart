import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SpeechModelSize { tiny, base }

/// User preferences, persisted with shared_preferences.
class SettingsController extends ChangeNotifier {
  SettingsController(this._prefs);

  final SharedPreferences _prefs;

  static Future<SettingsController> load() async =>
      SettingsController(await SharedPreferences.getInstance());

  ThemeMode get themeMode =>
      ThemeMode.values[_prefs.getInt('themeMode') ?? ThemeMode.system.index];
  set themeMode(ThemeMode v) => _setInt('themeMode', v.index);

  /// App UI language. English is the default regardless of device language.
  Locale get locale => Locale(_prefs.getString('locale') ?? 'en');
  set locale(Locale v) => _setString('locale', v.languageCode);

  String get languageA => _prefs.getString('languageA') ?? 'en';
  set languageA(String v) => _setString('languageA', v);

  String get languageB => _prefs.getString('languageB') ?? 'vi';
  set languageB(String v) => _setString('languageB', v);

  bool get voiceLabels => _prefs.getBool('voiceLabels') ?? true;
  set voiceLabels(bool v) => _setBool('voiceLabels', v);

  bool get autoReadAloud => _prefs.getBool('autoReadAloud') ?? false;
  set autoReadAloud(bool v) => _setBool('autoReadAloud', v);

  bool get saveAudio => _prefs.getBool('saveAudio') ?? true;
  set saveAudio(bool v) => _setBool('saveAudio', v);

  /// Silence (seconds) that closes a sentence.
  double get silenceSeconds => _prefs.getDouble('silenceSeconds') ?? 0.6;
  set silenceSeconds(double v) {
    _prefs.setDouble('silenceSeconds', v);
    notifyListeners();
  }

  SpeechModelSize get modelSize =>
      SpeechModelSize.values[_prefs.getInt('modelSize') ?? SpeechModelSize.tiny.index];
  set modelSize(SpeechModelSize v) => _setInt('modelSize', v.index);

  bool get adsRemoved => _prefs.getBool('adsRemoved') ?? false;
  set adsRemoved(bool v) => _setBool('adsRemoved', v);

  DateTime? get lastInterstitialAt {
    final ms = _prefs.getInt('lastInterstitialAt');
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  set lastInterstitialAt(DateTime? v) {
    if (v == null) {
      _prefs.remove('lastInterstitialAt');
    } else {
      _prefs.setInt('lastInterstitialAt', v.millisecondsSinceEpoch);
    }
  }

  String? get dismissedUpdateVersion => _prefs.getString('dismissedUpdate');
  set dismissedUpdateVersion(String? v) =>
      v == null ? _prefs.remove('dismissedUpdate') : _prefs.setString('dismissedUpdate', v);

  void _setInt(String k, int v) {
    _prefs.setInt(k, v);
    notifyListeners();
  }

  void _setString(String k, String v) {
    _prefs.setString(k, v);
    notifyListeners();
  }

  void _setBool(String k, bool v) {
    _prefs.setBool(k, v);
    notifyListeners();
  }
}
