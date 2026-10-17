# Voice Realtime Translater

Ứng dụng dịch hội thoại hai chiều cho Android và iOS (Flutter). Tự nhận diện ngôn ngữ đang nói, dịch sang ngôn ngữ còn lại, gắn nhãn giọng nam/nữ, đọc to bản dịch. Nhận dạng giọng nói và dịch đều chạy trên máy, miễn phí, không dùng dịch vụ AI trả phí.

## Công nghệ (tất cả miễn phí)

| Phần | Thư viện | Ghi chú |
|---|---|---|
| Ghi âm | `record` | PCM 16 kHz mono |
| Tách câu (VAD) | `sherpa_onnx` + Silero VAD | ngắt câu khi im lặng |
| Nhận dạng + tự nhận ngôn ngữ | `sherpa_onnx` + Whisper tiny/base (int8) | chạy trong isolate riêng, mô hình tải lần đầu |
| Dịch | `google_mlkit_translation` | gói ngôn ngữ ~30 MB, offline |
| Giọng nam/nữ | tự viết (`lib/services/voice_gender.dart`) | đo cao độ (F0) bằng tự tương quan |
| Đọc to | `flutter_tts` | engine TTS có sẵn của máy |
| Quảng cáo | `google_mobile_ads` | banner, native, interstitial chỉ sau khi bấm Kết thúc |
| Gỡ quảng cáo | `in_app_purchase` | sản phẩm `remove_ads` (non-consumable) |
| Cập nhật | `in_app_update` (Android/Play) + App Store lookup (iOS) + `update.json` | |
| Nhập/Xuất | `archive`, `file_picker`, `share_plus` | .zip (kèm âm thanh), .json, .txt, .srt |

## Cấu trúc

```
lib/
  core/        cấu hình, theme sáng/tối, ngôn ngữ, cài đặt
  data/        lưu phiên dịch, nhập/xuất
  l10n/        chuỗi giao diện EN (mặc định) + VI
  models/      Session, Segment
  services/    ghi âm, ASR, dịch, TTS, quảng cáo, mua hàng, cập nhật
  ui/          màn hình và widget (bố cục 2 cột khi rộng ≥ 840 px)
tool/setup_platforms.py   tạo + cấu hình android/ ios/ (quyền micro, AdMob, bundle id)
docs/store-listing.md     nội dung đăng Google Play / App Store
```

## Build tự động (GitHub Actions)

Mỗi lần push lên `main`, workflow `Build test apps` sẽ:
1. Tạo thư mục `android/` `ios/` nếu chưa có và áp cấu hình (lần đầu tự commit lại vào repo).
2. Chạy `flutter analyze` và `flutter test`.
3. Build **APK Android** (tải ở mục *Artifacts* → `android-apk`, cài `app-arm64-v8a-release.apk` cho hầu hết điện thoại) và **AAB** để đưa lên Google Play.
4. Build **iOS**: bản chạy trên Simulator và bản cho máy thật chưa ký.

### Cài thử
- **Android:** tải `android-apk`, giải nén, chép `app-arm64-v8a-release.apk` vào điện thoại và mở để cài (cho phép "cài từ nguồn không xác định").
- **iOS:** cần ký bằng tài khoản Apple Developer (99 USD/năm) để cài lên iPhone thật hoặc TestFlight. Trên máy Mac có Xcode: `python3 tool/setup_platforms.py && flutter run --release` khi đã cắm iPhone, hoặc mở `ios/Runner.xcworkspace`, chọn Team rồi Archive → TestFlight.

## Chạy trên máy của bạn

```bash
flutter pub get
python3 tool/setup_platforms.py
dart run flutter_launcher_icons
flutter run
```

## Dùng mã quảng cáo thật

Mặc định app dùng **mã test của Google**. Khi đã có tài khoản AdMob, thêm các *Repository secrets* (Settings → Secrets and variables → Actions):

`ADMOB_ANDROID_APP_ID`, `ADMOB_IOS_APP_ID`, `ADMOB_ANDROID_BANNER`, `ADMOB_ANDROID_INTERSTITIAL`, `ADMOB_ANDROID_NATIVE`, `ADMOB_IOS_BANNER`, `ADMOB_IOS_INTERSTITIAL`, `ADMOB_IOS_NATIVE`

## Báo cập nhật

- App tải từ Google Play: dùng Play In-App Update (tải ngầm rồi khởi động lại).
- iPhone: so sánh với phiên bản trên App Store rồi mở trang App Store.
- Bản test / dự phòng: sửa `update.json` trên repo `voice-realtime-translater-site` (tăng `latestVersion`, ghi `notes`, đặt `minVersion` để bắt buộc cập nhật).

Nhớ tăng `version:` trong `pubspec.yaml` mỗi lần phát hành.

## Chính sách bảo mật

https://cyan881990.github.io/voice-realtime-translater-site/privacy.html
