> Arşiv: Bu rapor eski oda düzenine aittir. Güncel üç odalı akış için [oda ilerleyişi](room-progression.md) belgesini kullanın.

# Oda 1 → Oda 2: ilk denge paketi — 1 Ekim 2026

Hedef: yeni oyunda, aktif oyuncunun 5.000 gerçek balon patlatıp yaklaşık 10–12 dakikada Üretim Tesisi'ne geçmesi. Oda 2 açılışı 10.000 coin; geçiş tabletin Odalar sekmesinden yapılır. Bu süre henüz insan oynanışıyla doğrulanmadı.

## Silahlar

- Başlangıç: mevcut iğne. `[1]` ile kuşanılır. Aynı renge alan patlatma iğneye özeldir; özel bonus balonları iğneyle açılır.
- Dart tabancası: `[2]`, sol tık veya basılı tutarak ateş. 28 m menzil, enerji tüketmez. Duvarlardan geçmez. Hızlı atış ışın sorgusuyla hesaplanır, hareket eden dart izi çizilir; balistik düşüş uygulanmaz. İlk doğrudan isabet, yakındaki sınırlı sayıda başka balona sekme yaptırır. Sekme duvardan geçmez ve iğneye özel bonus balonlarını açmaz.
- Sv.1: 650 patlatma + 750 coin, yaklaşık 4,2 atış/sn, aynı çizgide 2 delme + 2,2 m içindeki en fazla 2 sekme.
- Sv.2: 2.500 patlatma + 2.400 coin, 5 atış/sn, 3 delme + 2,6 m içindeki en fazla 3 sekme.
- Sv.3: 8.500 patlatma + 11.000 coin, 6,25 atış/sn, 5 delme + 3 m içindeki en fazla 5 sekme. Daha sonraki seviyeler sonraki odalara uzanır.
- İğne makrosu `[Z/T]`, satın alınmış Auto-Pop hızını ve enerji tüketimini kullanır. Manuel tıklama da saldırı bekleme süresini aşamaz. Silah değiştirmek makroyu kapatır.
- Mevcut güçlü minigun korunur. Rastgele minigun çılgınlığı ilk odada coin bonusuna dönüşür; sonraki odalarda mevcut bonus çalışır. Kalıcı minigun satın alma yolu bu paketin kapsamında değildir.

## Üretim

| Geliştirme | Gerçek patlatma eşiği | Coin | Boru başına balon/sn |
|---|---:|---:|---:|
| Başlangıç | 0 | 0 | 1,2 |
| Dökülme Sv.1 | 10 | 60 | 2 |
| Dökülme Sv.2 | 40 | 180 | 3 |
| İkinci boru | 300 | 400 | Mevcut akışı ikiye katlar |
| Dökülme Sv.3 | 150 | 450 | 4,5 |
| Dökülme Sv.4 | 500 | 1.400 | 6,5 |
| Dökülme Sv.5 | 2.000 | 4.500 | 9 |

Oda 1: en fazla 2 boru, nominal 18 balon/sn. Bir sonraki dökülme geliştirmesi 6.500 patlatmada açılır. İğne Auto-Pop ilk üç eşiği 50 / 400 / 2.000; alan patlatma ilk üç eşiği 200 / 1.000 / 3.500. Bu eşikler satın alma şartıdır; parayı başka yere harcayan oyuncu daha sonra satın alabilir.

## Hesap modeli ve sınırları

`tests/model_room_one.gd`, değerleri doğrudan ShopManager kataloğundan okur. 0,1 saniyelik adımlarla üretim, satın alma eşikleri ve coin bakiyesini hesaplar. Uygun ve karşılanabilen geliştirmeleri seçer; satın alma başına 2 saniye ekler. Varsayılan gelir 1,5 toplanmış coin/gerçek patlatmadır. Özel altın, görev ödülleri, prestij ve geçici bonuslar modele dahil değildir.

| Nominal üretimin patlatılan oranı | 5.000'e ulaşma |
|---|---|
| %100 | Önceki katalogla 9:23 |
| %90 | Önceki katalogla 10:21 |
| %85 | Önceki katalogla 10:55 |
| %75 | Önceki katalogla 12:16 |

Bu tabloda önceki katalogla yapılan tarihsel simülasyon korunmuştur; güncel dart ve dökülme fiyatlarıyla süre tahmini olarak kullanılmamalıdır. Oranlar varsayımdır: model nişan almaz, fizik çalıştırmaz, dart hizalanmasını veya iğne renk zincirini simüle etmez. Silahların teorik azami çıktısı gerçek oynanış çıktısı değildir. Geçerli süre, satın alma tercihi, toplama verimi ve balon dağılımıyla değişir.

İlk oynanışta mevcut debug analizinden şunlar karşılaştırılmalı:

1. İlk üretim geliştirmesinin alınma zamanı (yaklaşık ilk 30–60 saniye).
2. Dartın satın alındığı zaman ve patlatma sayısı.
3. Son dakikalarda PPS ile nominal üretim farkı; fizik bütçesi nedeniyle üretimin ne kadar yavaşladığı.
4. 5.000'e ulaşma ve odayı açma zamanı. Bekleme satın alma, hedef bulma, üretim veya coin toplama kaynaklı mı?

Eski kayıtlar kazanılmış puanı/geliştirmeleri korur; bu ilk oda denemesi yeni oyun üzerinden yapılmalıdır.

## Kontroller

`test_room_one.gd`: mağaza butonu, satın alma kilidi, silah görünürlüğü, delme ve sekme sınırı, duvar engeli, bekleme süresi, bonus koruması, UI ateş kilidi, minigundan dönüş, ücretli ilk oda açılışı ve ücretsiz tekrar geçiş, kayıt/yükleme ve yeni oyun.

Testler geçici `XDG_DATA_HOME=/tmp/balloon-room-...` kullanır. `--capture` seçeneği `/tmp/balloon-room-dart.png` dosyasına oyun görüntüsü alır.

## Coin fiyatı revizyonu — 2 Ekim 2026

Patlatma eşikleri önceki değerlerinde tutulur; satın alma temposu coin fiyatlarıyla ayarlanır. İlk seviye fiyatları: üretim 60, otomatik iğne 180, ikinci boru 400, dart 750, coin mıknatısı 300, kondisyon 250, splash 500 coin. Sonraki seviyelerdeki fiyat artışları da korunur. Ürünlerin birlikte açılması mümkündür; oyuncunun bütçesi satın alma sırasını belirler. Birikmiş para veya bonus gelirleri toplu alışverişe hâlâ izin verebilir.

Önceki eşik değişiklikleriyle hesaplanan alışveriş aralıkları ve süreler bu katalog için geçerli değildir. Mevcut modelin 1,5 coin/patlatma varsayımı normal tier 1 gelirini temsil etmez; oynanış süresi için gerçek toplama ve bonus verileri gerekir.

Oda açılış bedelleri: Oda 2 = 10.000, Oda 3 = 100.000, Oda 4 = 750.000 coin. Patlatma eşikleri 5.000 / 60.000 / 350.000 olarak korunur. Önceden açılmış odalardan yeniden ücret alınmaz. Bunlar yeni denge değerleridir; mevcut üretim simülasyonları oda ücretlerini ödemeden eşikte geçiş yaptığı için gerçek oda geçiş süresi olarak kullanılamaz.
