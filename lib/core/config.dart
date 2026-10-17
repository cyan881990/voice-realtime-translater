import 'dart:io';

/// Build-time configuration. Real AdMob IDs are passed with --dart-define so they
/// never live in source control; Google's test IDs are used otherwise.
class AppConfig {
  AppConfig._();

  static const String bundleId = 'com.cyan.voicerealtimetranslater';

  /// Public page with the privacy policy (GitHub Pages).
  static const String privacyPolicyUrl =
      'https://cyan881990.github.io/voice-realtime-translater-site/privacy.html';

  /// Remote manifest used to announce updates to testers and iOS users.
  static const String updateManifestUrl =
      'https://cyan881990.github.io/voice-realtime-translater-site/update.json';

  /// Store product id for the one-time "remove ads" purchase.
  static const String removeAdsProductId = 'remove_ads';

  static const _androidBannerEnv = String.fromEnvironment('ADMOB_ANDROID_BANNER');
  static const _androidBannerTest = 'ca-app-pub-3940256099942544/9214589741';
  static const _iosBannerEnv = String.fromEnvironment('ADMOB_IOS_BANNER');
  static const _iosBannerTest = 'ca-app-pub-3940256099942544/2435281174';
  static const _androidInterstitialEnv = String.fromEnvironment('ADMOB_ANDROID_INTERSTITIAL');
  static const _androidInterstitialTest = 'ca-app-pub-3940256099942544/1033173712';
  static const _iosInterstitialEnv = String.fromEnvironment('ADMOB_IOS_INTERSTITIAL');
  static const _iosInterstitialTest = 'ca-app-pub-3940256099942544/4411468910';
  static const _androidNativeEnv = String.fromEnvironment('ADMOB_ANDROID_NATIVE');
  static const _androidNativeTest = 'ca-app-pub-3940256099942544/2247696110';
  static const _iosNativeEnv = String.fromEnvironment('ADMOB_IOS_NATIVE');
  static const _iosNativeTest = 'ca-app-pub-3940256099942544/3986624511';

  /// An empty --dart-define (e.g. an unset CI secret) falls back to the test ID.
  static String _pick(String env, String test) => env.isEmpty ? test : env;

  static String get bannerAdUnit => Platform.isIOS
      ? _pick(_iosBannerEnv, _iosBannerTest)
      : _pick(_androidBannerEnv, _androidBannerTest);
  static String get interstitialAdUnit => Platform.isIOS
      ? _pick(_iosInterstitialEnv, _iosInterstitialTest)
      : _pick(_androidInterstitialEnv, _androidInterstitialTest);
  static String get nativeAdUnit => Platform.isIOS
      ? _pick(_iosNativeEnv, _iosNativeTest)
      : _pick(_androidNativeEnv, _androidNativeTest);

  /// Minimum gap between two interstitials, and minimum session length to show one.
  static const Duration interstitialCooldown = Duration(minutes: 3);
  static const Duration minSessionForInterstitial = Duration(seconds: 20);
}
