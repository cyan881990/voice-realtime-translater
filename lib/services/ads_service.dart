import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../core/config.dart';
import '../core/settings_controller.dart';

/// AdMob: consent, adaptive banners, native ads and an interstitial that is
/// only ever shown after a session has ended (never while recording).
class AdsService {
  AdsService(this._settings);

  final SettingsController _settings;
  InterstitialAd? _interstitial;
  bool _initialized = false;

  bool get enabled => !_settings.adsRemoved;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    await _gatherConsent();
    await MobileAds.instance.initialize();
    preloadInterstitial();
  }

  /// Google UMP consent form (shown only where required, e.g. EEA/UK).
  Future<void> _gatherConsent() async {
    final done = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () async {
        try {
          await ConsentForm.loadAndShowConsentFormIfRequired((_) {
            if (!done.isCompleted) done.complete();
          });
        } catch (_) {
          if (!done.isCompleted) done.complete();
        }
      },
      (_) {
        if (!done.isCompleted) done.complete();
      },
    );
    await done.future.timeout(const Duration(seconds: 8), onTimeout: () {});
  }

  void preloadInterstitial() {
    if (!enabled || _interstitial != null) return;
    InterstitialAd.load(
      adUnitId: AppConfig.interstitialAdUnit,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitial = ad,
        onAdFailedToLoad: (_) => _interstitial = null,
      ),
    );
  }

  /// Call after the user taps End. Completes when the ad is closed (or
  /// immediately when no ad is shown).
  Future<void> showAfterSession(Duration sessionLength) async {
    if (!enabled) return;
    final last = _settings.lastInterstitialAt;
    final cooledDown =
        last == null || DateTime.now().difference(last) > AppConfig.interstitialCooldown;
    final ad = _interstitial;
    if (ad == null || !cooledDown || sessionLength < AppConfig.minSessionForInterstitial) {
      preloadInterstitial();
      return;
    }
    final closed = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        if (!closed.isCompleted) closed.complete();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        if (!closed.isCompleted) closed.complete();
      },
    );
    _interstitial = null;
    _settings.lastInterstitialAt = DateTime.now();
    await ad.show();
    await closed.future;
    preloadInterstitial();
  }
}

/// Anchored adaptive banner that sizes itself to the available width.
class BannerAdSlot extends StatefulWidget {
  const BannerAdSlot({super.key, required this.settings});
  final SettingsController settings;

  @override
  State<BannerAdSlot> createState() => _BannerAdSlotState();
}

class _BannerAdSlotState extends State<BannerAdSlot> {
  BannerAd? _ad;
  bool _loaded = false;
  int? _width;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final w = MediaQuery.sizeOf(context).width.truncate();
    if (w != _width) {
      _width = w;
      _load(w);
    }
  }

  Future<void> _load(int width) async {
    if (widget.settings.adsRemoved) return;
    _ad?.dispose();
    setState(() => _loaded = false);
    final size = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(width.clamp(320, 728));
    if (!mounted || size == null) return;
    final ad = BannerAd(
      adUnitId: AppConfig.bannerAdUnit,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, _) => ad.dispose(),
      ),
    );
    _ad = ad;
    await ad.load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (widget.settings.adsRemoved || ad == null || !_loaded) {
      return const SizedBox.shrink();
    }
    return SafeArea(
      top: false,
      child: Center(
        child: SizedBox(
          width: ad.size.width.toDouble(),
          height: ad.size.height.toDouble(),
          child: AdWidget(ad: ad),
        ),
      ),
    );
  }
}

/// Small native ad (Google template) for placement inside lists.
class NativeAdCard extends StatefulWidget {
  const NativeAdCard({super.key, required this.settings});
  final SettingsController settings;

  @override
  State<NativeAdCard> createState() => _NativeAdCardState();
}

class _NativeAdCardState extends State<NativeAdCard> {
  NativeAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    if (widget.settings.adsRemoved) return;
    _ad = NativeAd(
      adUnitId: AppConfig.nativeAdUnit,
      request: const AdRequest(),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.small,
        cornerRadius: 16,
      ),
      listener: NativeAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, _) => ad.dispose(),
      ),
    )..load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (ad == null || !_loaded) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 90, maxHeight: 120),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AdWidget(ad: ad),
        ),
      ),
    );
  }
}
