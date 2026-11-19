---
title: Müzik Yok — Gizlilik Politikası
---

# Müzik Yok — Gizlilik Politikası

_Son güncelleme: 19 Kasım 2026_

Müzik Yok, odaklı düşünme oturumları sırasında çevredeki müziği fark etmenize ve dikkat dağıtan uygulamaları sınırlamanıza yardımcı olan bir iPhone uygulamasıdır. Bu politika, uygulamanın hangi verilere eriştiğini ve bunları nasıl kullandığını açıklar.

## Özet

- Hesap yoktur, oturum açılmaz.
- Reklam, analiz veya izleme (tracking) araçları kullanılmaz.
- Ses kaydedilmez ve hiçbir ses dosyası saklanmaz.
- Notlarınız yalnızca iPhone'unuzda saklanır; bulut eşitlemesi yoktur.
- Geliştiriciye hiçbir kişisel veri gönderilmez.

## Eriştiğimiz izinler

| İzin | Neden | Veri cihazdan çıkar mı? |
|---|---|---|
| Mikrofon | Düşünme Modu açıkken çevrede müzik çalıp çalmadığını cihaz üzerinde algılamak | Hayır. Yalnızca şarkı tanıma için kısa bir ses imzası (aşağıya bakın) |
| Bildirimler | Oturum bittiğinde ve müzik algılandığında sizi uyarmak | Hayır |
| Ekran Süresi (Family Controls) | Oturum boyunca seçtiğiniz uygulamaları geçici olarak sınırlamak | Hayır. Seçtiğiniz uygulamaların listesini Apple şifreli simgeler (token) olarak verir; uygulama bunların adlarını göremez |

## Şarkı tanıma (ShazamKit)

Müzik algılandığında, Apple'ın ShazamKit hizmeti kullanılarak çalan parça tanınmaya çalışılır. Bu işlemde ham ses değil, sesten çıkarılan ve geri sese dönüştürülemeyen kısa bir **ses imzası** Apple'ın Shazam kataloğunda aranır. Bu işlem Apple'ın [gizlilik politikasına](https://www.apple.com/legal/privacy/) tabidir. Müzik Yok bu imzayı saklamaz.

## Cihazda saklanan veriler

- Oturum notlarınız ve oturum geçmişi
- Açık/koyu tema tercihi
- Ekran Süresi'nde seçtiğiniz uygulamalar (Apple'ın şifreli simgeleri olarak)
- Devam eden oturumun bitiş zamanı

Bu verilerin tamamı uygulamanın iPhone'daki alanında tutulur. Notlarınızı uygulama içindeki **Notlarım** sayfasından tek tek veya topluca silebilirsiniz. Uygulamayı sildiğinizde tüm veriler de silinir.

## Çocuklar

Uygulama çocuklara yönelik değildir ve kimseden kişisel veri toplamaz.

## Değişiklikler

Bu politika değişirse güncel hali bu sayfada yayımlanır ve yukarıdaki tarih güncellenir.

## İletişim

Sorularınız için: [GitHub Issues](https://github.com/derindvc/muzik-yok/issues)

---

# Müzik Yok — Privacy Policy (English)

_Last updated: November 19, 2026_

Müzik Yok does **not** collect, store on a server, or share any personal data. There are no accounts, ads, analytics or tracking.

- **Microphone** is used only while a Thinking Mode session is running, to detect ambient music on device. No audio is recorded or saved.
- **Song recognition** uses Apple ShazamKit: a short, non-reversible audio signature (not raw audio) is matched against Apple's Shazam catalog, subject to [Apple's privacy policy](https://www.apple.com/legal/privacy/).
- **Notifications** are local and used for session-end and music alerts.
- **Screen Time (Family Controls)** is used to temporarily limit apps you choose. Apple provides these as opaque tokens; the app cannot see app names.
- **Notes**, session history and preferences stay on your iPhone and can be deleted in the app at any time. Deleting the app deletes all data.

Questions: [GitHub Issues](https://github.com/derindvc/muzik-yok/issues).
