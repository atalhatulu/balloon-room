# Oda Kısıtlamaları ve Pompalı Dart (Shotgun) İyileştirme Raporu

## 1. Mimari Kararlar & Kısıtlamalar
- **Önceki Durum:**
  - Oda 1'deyken oyuncu tablet marketten tüm yükseltmeleri sınırsızca alabiliyordu. Bu durum oda geçişlerinin (Oda 1 → Oda 2 → Oda 3) ilerleme hissini ve motivasyonunu zayıflatıyordu.
  - Pompalı dart (Shotgun) dar konik açıda, 8 saçma ve 2 delme değerine sahipti. Kalabalık ve çok cana sahip balonlarda süpürme hissi yetersiz kalıyordu.
- **Uygulanan Çözüm:**
  - `ShopManager` içerisine merkezi `get_upgrade_room_cap(upgrade_id)` sistemi eklendi.
  - Tablet market kartlarında oda tavanına ulaşıldığında kilit mesajı verilerek satın alma engellendi.
  - Pompalı dart 12–24 saçma, 3–10 delme, yatay fan saçılma ve akustik patlama şoku ile baştan tasarlandı.

---

## 2. Oda Bazlı Satın Alma Sınırları

### Oda 1 (Başlangıç Atölyesi / Small Room)
- **Boru Sınırı:** En fazla 2 boru
- **Zemin Otomasyon Cihazları:** Kilitli (0 cihaz)
- **Kondisyon:** Maksimum Sv. 4
- **Auto-Pop:** Maksimum Sv. 3
- **Splash (Alan Patlatma):** Maksimum Sv. 3
- **Dart Tabancası:** Maksimum Sv. 2
- **Pompalı Dart:** Kilitli (Sv. 0)
- **Minigun:** Kilitli (Sv. 0)
- **Coin Mıknatısı:** Maksimum Sv. 3
- **Menfez Akış Hızı:** Maksimum Sv. 5
- **Dron:** Kilitli (Sv. 0)

### Oda 2 (Üretim Tesisi / Medium Room)
- **Boru Sınırı:** En fazla 4 boru
- **Zemin Otomasyon Cihazları:** En fazla 8 cihaz
- **Kondisyon:** Maksimum Sv. 6
- **Auto-Pop:** Maksimum Sv. 5
- **Splash (Alan Patlatma):** Maksimum Sv. 5
- **Dart Tabancası:** Maksimum Sv. 4
- **Pompalı Dart:** Maksimum Sv. 3 (Burada açılır)
- **Minigun:** Kilitli (Sv. 0)
- **Coin Mıknatısı:** Maksimum Sv. 5
- **Menfez Akış Hızı:** Maksimum Sv. 7
- **Dron:** Maksimum Sv. 2

### Oda 3 (Mega Hangar / Hangar)
- **Boru Sınırı:** En fazla 9 boru
- **Zemin Otomasyon Cihazları:** En fazla 16 cihaz
- **Kondisyon:** Maksimum Sv. 8
- **Auto-Pop:** Maksimum Sv. 7
- **Splash (Alan Patlatma):** Maksimum Sv. 7
- **Dart Tabancası:** Maksimum Sv. 5
- **Pompalı Dart:** Maksimum Sv. 5
- **Minigun:** Maksimum Sv. 3 (Burada açılır)
- **Coin Mıknatısı:** Maksimum Sv. 7
- **Menfez Akış Hızı:** Maksimum Sv. 10
- **Dron:** Maksimum Sv. 4

---

## 3. Pompalı Dart (Shotgun Dart) Revizyonu
1. **Saçma & Delme Gücü:** 8 saçmadan **12–24 saçmaya**, delme adedi 2'den **3–10 delmeye** çıkarıldı.
2. **Yatay Fan Saçılma (Horizontal Fan Spread):** Saçılma konisi yatayda geniş (`spread_angle * 1.55`), dikeyde dar (`spread_angle * 0.75`) eliptik biçime getirildi; koridorlar tek atışta süpürülür.
3. **Seri Pompalama & Şarjör:** Atış aralığı 0.65s'den **0.45s - 0.22s**'ye düşürüldü. Şarjör kapasitesi 6'dan **8–20 mermiye** artırıldı.
4. **Çoklu Can Desteği (`take_hit`):** Saçmaların her biri dayanıklı balonlara ardışık hasar verir.
5. **Kamera & Ses Geri Bildirimi:** Atış anında kamerada yukarı yönlü tepme darbesi, namlu önünde patlama şok dalgası (`spawn_shockwave_vfx`) ve -4.0 dB güçlü sub-bass patlama sesi uygulandı.
