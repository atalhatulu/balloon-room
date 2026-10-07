> Arşiv: Bu rapor eski oda düzenine aittir. Güncel üç odalı akış için [oda ilerleyişi](room-progression.md) belgesini kullanın.

# Oda 2 — Üretim Tesisi ve otomasyon (1 Ekim 2026)

## Oynanabilir ilerleme

Başlangıç atölyesinden 5.000 **gerçek balon patlatınca** ücretsiz geçilir. Üretim Tesisi'nden Hangar'a eşik 60.000, Siber Laboratuvar'a eşik 350.000, nihai hedef 1.000.000 gerçek patlatmadır. İkinci odanın bölümü 55.000 ek balondur. Yaklaşık 16 dakikalık hedef için bölüm boyunca ortalama 57,3 patlatma/sn gerekir. Bu bir tasarım hedefidir; oyuncu denemesiyle henüz doğrulanmadı.

Tesis 38×38 m, 4 boru ve 8 kurulu cihaz sınırındadır. Aynı türden en fazla 2 cihaz, cihaz teknolojisinde en fazla seviye 3 alınabilir. Üretim akışı ve cihaz alımı coin gerektirir; oda açılışı ayrıca coin tüketmez. Kargo servis alanından alınıp içeride yerleştirilir. Oda büyüyünce kurulu cihazlar konumlarını alanla orantılı korur. İlk odada otomasyon satın alınamaz.

| Gerçek patlatma | Açılan cihaz | İşlev |
|---:|---|---|
| 5.000 | Endüstriyel zemin kırıcısı | Üstünden geçen fiziksel balonları patlatır |
| 7.000 | Yönlendirme vantilatörü | Balonları baktığı yönde iter; patlatmaz |
| 9.000 | Manyetik çekim kulesi | Yakındaki balonları cihazlara doğru toplar; patlatmaz |
| 30.000 | EMP ızgarası | Aralıklı alan patlatması yapar |

Vantilatörün yönü yerleştirirken `R` ile değişir. Cihaz kartlarında teorik hız gösterilir; tesis ekranı son 10 saniyedeki **gerçek** patlatma veya temas sayısını gösterir. Değerli balonun puan/coin katsayısı fiziksel patlatma sayısını artırmaz. Cihaz fiyatları ve teknoloji eşikleri `src/core/shop_manager.gd` kataloğundan okunur.

## Görünüm

Üretim alanlarını tanımlayan dört zemin çerçevesi ve HAT 01–04 işaretleri, iki uzun tavan ışık rayı, duvarlarda dönen havalandırma rotorları ve akan durum ışıkları eklendi. Rotor üretim durumuna göre hızlanır veya yavaşlar, elektrik kesintisinde durur; dekorasyon balon patlatmaz. HUD oda kimliğini ve sonraki eşiği gösterir. Dart kuşanma ve geri tepme hareketi ile market kartlarının açılma ve satın alma geri bildirimi genişletildi.

## Sıradaki tasarım işi

İkinci odayı oynayarak 5.000→60.000 süresi, coin toplama hızı, üretim ve patlatma oranı ölçülmeli. İlk kırıcının giriş anındaki yerleşimi ve 7.000/9.000 eşiklerindeki fan/mıknatıs etkisi ayrı gözlenmeli. Yeni bir cihaz eklemeden önce bu üçlünün birlikte çalışıp çalışmadığı anlaşılmalı. Daha sonra ayrı rolü olan hazneli sıkıştırıcı düşünülebilir; mevcut `conveyor_crusher` sahnesi incelenerek tekrar yapım önlenir.

Mevcut oda geçişi tabletin Odalar sekmesinden yapılır. Ayrı geçiş kapısı önerisi taslak olarak duruyor; geçişte kargo, cihaz ve kayıt durumunun korunması gerekir.

## Teknik denge sınırı

`tests/audit_room_balance.gd` boru zamanlayıcısını ideal, her balonu anında tüketen bir sistemle ölçer. Bu test fizik, hedef alma, coin kısıtı ve oyuncu kararlarını içermez. Üretim tavanı ve gerçek oynanış gereksinimi için `docs/balance-audit.md` kullanılmalıdır.
