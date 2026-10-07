> Arşiv: Bu rapor eski oda düzenine aittir. Güncel üç odalı akış için [oda ilerleyişi](room-progression.md) belgesini kullanın.

# Oda üretimi ve 1 milyon hedefi — 1 Ekim 2026

İlerleme sayacı her fiziksel balon patladığında bir artar. 5 ve 50 değerli balonlar da toplam patlatmaya yalnız bir ekler. Oda eşikleri 5.000 / 60.000 / 350.000, bitiş hedefi 1.000.000'dir. Oda açılışları ücretsizdir.

| Oda | Bölümde gerekli patlatma | Sonraki eşiğe yakın nominal üretim | Eşikte mümkün boru | Fiziksel balon bütçesi |
|---|---:|---:|---:|---:|
| Atölye | 5.000 | 18/sn | 2 | 380 |
| Üretim Tesisi | 55.000 | 110/sn | 4 | 480 |
| Hangar | 290.000 | 475,2/sn | 6 | 600 |
| Siber Laboratuvar | 650.000 | 1.232/sn | 8 | 720 |

Bu nominal hızlar, sonraki eşikten **önce** açılabilen tüm dökülme ve boru geliştirmelerinin alınmış olduğunu varsayar. `tests/audit_room_balance.gd` zamanlayıcıyı 30, 60 ve 144 FPS'de 10 saniye çalıştırdığında her odada beklenen sayıyla ±1 balon içinde eşleşti. Bu, ideal tüketiciyle yapılan zamanlayıcı ölçümüdür. Oyun içinde fizik bütçesi dolarsa veya balonlar patlatılamazsa gerçek üretim düşer. Tesis ekranı gerçek son 10 saniye üretimini gösterir.

Sınırsız coin, anında geliştirme ve gelen her balonun anında patlatılması varsayımlarıyla bölüm alt süreleri sırasıyla 397,8 / 629,6 / 834,0 / 638,8 saniye; toplam yaklaşık 41,7 dakikadır. Bir saat hedefi için gerçek oynanışın bu ideal akışın altında kalacağı öngörülür, fakat 60 dakika sonucu kanıtlanmış değildir. Özellikle 3. ve 4. odalarda fizik bütçesi, cihaz teması, yerleşim ve coin ekonomisi birlikte ölçülmelidir.

İlk oynanış kaydında her oda giriş/çıkış zamanı, gerçek patlatma/sn, gerçek üretim/sn, fiziksel balon doluluğu, coin ve cihazların son 10 saniye çıktısı izlenmeli. Üretim yeterliyken patlatma düşükse cihaz beslemesi veya yerleşimi; üretim düşükse boru geliştirmesi, dolu fizik bütçesi veya kapalı üretim incelenmeli. Sayılar buna göre oda oda ayarlanmalı.

Kısa oyun denemelerinin F1 verisiyle nasıl analiz edileceği ve güncel katalogdan çalışan ekonomi senaryoları `docs/balance-testing.md` içinde açıklanır.
