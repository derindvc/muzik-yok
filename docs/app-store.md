# App Store yayın rehberi

Bu dosya, Müzik Yok'u App Store'a göndermek için gereken metinleri ve adımları bir arada tutar.

## 1. Ön koşullar (yalnızca hesap sahibi yapabilir)

| Adım | Nerede | Not |
|---|---|---|
| Apple Developer Program üyeliği | developer.apple.com/programs | Yıllık ücretlidir (99 USD). Ücretsiz "Personal Team" ile App Store'a gönderilemez. |
| App ID'ler | Certificates, IDs & Profiles → Identifiers | `com.allenbarry.muzikyok`, `.ThinkingMonitorExtension`, `.LiveActivityExtension` |
| ShazamKit hizmeti | Ana App ID → App Services | Şarkı tanıma için zorunlu |
| Family Controls yetkisi | Ana App ID ve `ThinkingMonitorExtension` | Geliştirme sürümü hemen açılır |
| **Family Controls (Distribution) onayı** | developer.apple.com/contact/request/family-controls-distribution | **App Store için zorunlu.** Apple'ın onayı günler veya haftalar sürebilir. Her iki App ID için ayrı istenir. |
| App Store Connect kaydı | appstoreconnect.apple.com → Uygulamalar → + | Bundle ID: `com.allenbarry.muzikyok`, SKU: `muzikyok-ios` |

## 2. Derleme ve yükleme

```bash
flutter clean
flutter pub get
flutter build ipa --release
```

Çıktı `build/ios/ipa/` altına düşer. Yüklemek için Xcode → Window → Organizer → Distribute App veya Apple'ın **Transporter** uygulaması kullanılır. Her yeni yüklemede `pubspec.yaml` içindeki derleme numarası (`1.0.0+1` → `1.0.0+2`) artırılmalıdır.

## 3. App Store Connect metinleri

**Uygulama adı (30):** Müzik Yok
**Alt başlık (30):** Sessizlikte odaklan
**Kategori:** Verimlilik (ikincil: Sağlık ve Fitness)
**Yaş sınırı:** 4+
**Fiyat:** Ücretsiz

**Tanıtım metni (170):**
Düşünmeye ayırdığın süreyi koru. Müzik Yok çevrede müzik çaldığında seni uyarır, dikkat dağıtan uygulamaları oturum boyunca sınırlar.

**Açıklama:**

Bazı düşünceler sessizlik ister. Müzik Yok, kendine ayırdığın düşünme süresini korumana yardım eder.

Süreni seç, Düşünme Modu'nu başlat ve gerisini uygulamaya bırak:

• Çevre müziği algılama — Arka planda müzik çalmaya başladığında iPhone seni nazikçe uyarır. Algılama tamamen cihaz üzerinde yapılır; ses kaydedilmez.
• Şarkı tanıma — Çalan parçayı ShazamKit ile tanır ve ekranda gösterir.
• Uygulama sınırlama — 15 dakika ve üzeri oturumlarda seçtiğin uygulamaları Ekran Süresi ile geçici olarak kilitler.
• Notlar — Oturum sırasında aklına gelenleri hızlıca kaydet, sonra Notlarım sayfasından gözden geçir.
• Canlı Etkinlik — Kalan süreyi kilit ekranında ve Dynamic Island'da gör.
• Açık ve koyu tema.

Hesap yok, reklam yok, izleme yok. Notların yalnızca senin iPhone'unda kalır.

**Anahtar kelimeler (100):** odak,düşünme,sessizlik,konsantrasyon,zamanlayıcı,pomodoro,ekran süresi,dikkat,not,meditasyon

**Destek URL'si:** https://github.com/derindvc/muzik-yok/issues
**Gizlilik politikası URL'si:** https://derindvc.github.io/muzik-yok/privacy-policy

## 4. Uygulama Gizliliği (App Privacy) formu

"Veri toplamıyoruz" (**Data Not Collected**) seçilir. Gerekçe: hiçbir veri geliştiriciye veya üçüncü tarafa gönderilmez; ShazamKit eşleştirmesi Apple'ın kendi hizmetidir ve uygulama sonucu saklamaz.

## 5. İnceleme ekibine not (App Review Notes)

> Müzik Yok is a focus timer. When a session starts, the app listens to the microphone on device (Sound Analysis) to detect ambient music and alerts the user; no audio is recorded. ShazamKit is used to show the name of the detected song. The `audio` background mode keeps detection running while the phone is locked during an active session only; it stops when the session ends or the user taps Exit.
>
> For sessions of 15 minutes or longer, the user may pick apps to shield via the Screen Time picker (FamilyControls, individual authorization). The shield is removed automatically by a DeviceActivity monitor extension when the session ends, or immediately when the user exits.
>
> To test: open the app → tap the duration → choose 15 min → select apps → Start → play any music near the device.

## 6. Ekran görüntüleri

App Store en az bir set ister: **6.9" iPhone (1320 × 2868)**. Önerilen sıra:

1. Ana ekran (süre ve Başlat)
2. Süre seçimi
3. Oturum geri sayımı
4. Müzik uyarısı
5. Notlarım

Simülatörde almak için: `flutter run -d "iPhone 17 Pro Max"` → Simulator → File → Save Screen (⌘S).

## 7. Sık karşılaşılan red nedenleri

- **Guideline 2.5.4 (arka plan sesi):** `audio` arka plan modu yalnızca aktif oturumda kullanılmalı. İnceleme notunda açıklandı.
- **Guideline 5.1.1 (izin metinleri):** Mikrofon açıklaması `Info.plist` içinde mevcut ve amacı açıkça anlatıyor.
- **Family Controls Distribution onayı yoksa** yükleme sırasında imzalama hatası alınır.
