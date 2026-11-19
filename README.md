<p align="center">
  <img src="docs/assets/icon.png" width="128" alt="Müzik Yok app icon">
</p>

<h1 align="center">Müzik Yok</h1>

<p align="center">
  A focus timer for iPhone that detects ambient music on device and shields distracting apps while you think.
</p>

<p align="center">
  <img alt="Platform" src="https://img.shields.io/badge/platform-iOS%2016%2B-black">
  <img alt="Flutter" src="https://img.shields.io/badge/Flutter-3.47-02569B?logo=flutter">
  <img alt="Swift" src="https://img.shields.io/badge/Swift-native%20bridges-F05138?logo=swift&logoColor=white">
  <img alt="License" src="https://img.shields.io/badge/license-MIT-green">
</p>

> 🇹🇷 Türkçe özet [aşağıda](#türkçe).

## Overview

Some thinking needs silence. **Müzik Yok** ("No Music") lets you start a timed *Thinking Mode* session. While it runs, the app:

- **Listens for music on device.** Apple's Sound Analysis classifier runs locally. Two consecutive windows of music or singing at ≥ 0.40 confidence trigger an alert, repeated every 8 s while the music continues.
- **Recognizes the song** with ShazamKit and shows the title and artist.
- **Works in the background.** When the phone is locked, ShazamKit matches and a lightweight on-device melody detector (stable, changing pitch over several seconds) keep alerts coming as local notifications and haptics.
- **Shields distracting apps** through the Screen Time API (FamilyControls + ManagedSettings). A DeviceActivity monitor extension lifts the shield automatically when the session ends.
- **Shows a Live Activity** on the Lock Screen and in the Dynamic Island.
- **Captures notes** during the session, with a short reflection screen at the end.

There are no accounts, ads, analytics or tracking. Audio is never recorded, and notes stay on the device. See the [privacy policy](docs/privacy-policy.md).

## Architecture

```
lib/main.dart                  Flutter UI: timer, duration picker, session, notes, theme
        │  MethodChannel
        ▼
ios/Runner/
  AppDelegate.swift            Audio engine, Sound Analysis, ShazamKit, melody detector,
                               haptics (CoreHaptics), local notifications, persistence
  ScreenTimeBridge.swift       FamilyActivityPicker (SwiftUI), ManagedSettings shield,
                               DeviceActivity schedule
  ThinkingLiveActivity.swift   ActivityKit start/update/end
ios/ThinkingMonitorExtension/  DeviceActivityMonitor: clears the shield when time is up
ios/LiveActivityExtension/     WidgetKit Live Activity and Dynamic Island UI
ios/Shared/                    ActivityAttributes shared by the app and the widget
```

**Design choices**

- **Flutter for UI, native Swift for platform features.** Sound Analysis, ShazamKit, Screen Time and ActivityKit have no cross-platform equivalents, so they sit behind a thin MethodChannel API.
- **Restart-safe sessions.** The end time is persisted, so a session that ends while the app is suspended or killed still finishes correctly. A local notification is also scheduled for the end time.
- **Fewer false positives.** Detection needs consecutive positive windows and strong pitch thresholds. A "false detection" button pauses alerts for two minutes.
- **Clear about limits.** iOS doesn't allow DeviceActivity schedules shorter than 15 minutes, so app shielding only turns on at 15 minutes or more. The user can always revoke Screen Time access, so the app never promises a lock that can't be bypassed.

## Getting started

Requirements: macOS with Xcode 16+, Flutter 3.47+, and an iPhone running iOS 16 or later. Sound Analysis and Screen Time need a real device.

```bash
flutter pub get
flutter run -d <device-id>
```

Open `ios/Runner.xcworkspace` in Xcode to change the signing team. The FamilyControls and ShazamKit capabilities must be enabled for the App IDs in your Apple Developer account.

```bash
flutter analyze
flutter test
```

## Project status

| Area | Status |
|---|---|
| iOS app | Feature-complete, preparing for App Store submission |
| Android | UI prototype only (no music detection or app blocking) |

Release checklist and App Store copy: [docs/app-store.md](docs/app-store.md).

## License

[MIT](LICENSE)

---

## Türkçe

**Müzik Yok**, düşünmeye ayırdığın süreyi korumak için tasarlanmış bir iPhone uygulamasıdır. Düşünme Modu açıkken:

- Çevrede müzik çaldığında cihaz üzerinde algılar ve uyarır. Ses kaydedilmez.
- Çalan şarkıyı ShazamKit ile tanır.
- 15 dakika ve üzeri oturumlarda seçtiğin uygulamaları Ekran Süresi ile geçici olarak sınırlar.
- Kalan süreyi Canlı Etkinlik olarak kilit ekranında gösterir.
- Oturum sırasında not almanı sağlar. Notlar yalnızca iPhone'da saklanır.

Hesap, reklam veya izleme yoktur. Ayrıntılar için [gizlilik politikasına](docs/privacy-policy.md), yayın adımları için [App Store rehberine](docs/app-store.md) bakabilirsin.
