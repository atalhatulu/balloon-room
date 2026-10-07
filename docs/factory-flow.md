# Üretim ve kargo akışı

- Tablet marketindeki zemin cihazları teslimat kuyruğuna girer. Coin ve cihaz kapasitesi sipariş sırasında ayrılır.
- Güney duvarındaki turuncu düğme: E ile borulardan yeni balon gelişini durdur/başlat. Odadaki mevcut balonlar ve cihazlar çalışmaya devam eder.
- Mavi düğme veya kapı: E ile servis kapısını aç/kapat. Üretim açıkken kapı açılmaz; kapı açıkken, hareket ederken veya oyuncu dışarıdayken üretim başlamaz.
- Dış teslimat alanındaki kutu: E ile al. Odaya dönünce E ile aç; sol tık/E ile yerleştir, R ile döndür, Q/sağ tık ile iptal et.
- Kurulumu iptal edilen kargo tekrar teslimat kuyruğuna döner. Satın alım kaybolmaz ve tekrar ücret alınmaz. Kayıt sırasında eldeki paket de kuyrukta saklanır; yüklemede oyuncu içeride ve kapı kapalı başlar.
- Yerleştirmede cihaz tabanı ve etki halkası gösterilir; oda sınırı, mobilya, diğer cihazlar ve servis koridoru kontrol edilir. Taşınan cihaz çalışmaz.
- Oda değişiminde cihaz dağılımı boyuta göre ölçeklenir. Çakışmalar için yeni yer aranır; sığmayan veya oda cihaz sınırını aşan cihazlar yeniden paketlenir.
- Cihaz göstergeleri son 10 saniyedeki gerçek patlatmaları gösterir. Mıknatıs göstergesi çekim uygulanan farklı balonları sayar; patlatma iddiasında bulunmaz.
- Yerçekimi modları: 0.25 / 0.75 / 1.60 / 3.20 / 6.00 G. Yükseltme yeni modu açar; terminalde E ile seçilir.
- Market yükseltme kartları mevcut/sonraki değeri gösterir. Cihaza bakarken menzil ve bekleme süresinin mevcut/sonraki değeri de görünür.

## Performans

Mobilya ve HVAC kutuları malzeme başına MultiMesh ile çizilir; çarpışmalar ve yazılar korunur. Fiziksel balon bütçesi oda başına 380 / 480 / 600 / 720; ağırlıklı balon kapasitesi bundan ayrıdır. Bunlar üst sınırlardır, FPS garantisi değildir.

## Doğrulama

Oyuncu kaydına dokunmadan test etmek için:

```sh
XDG_DATA_HOME=/tmp/balloon-room-factory-tests godot --headless --path . --script res://tests/test_factory_flow.gd
```

49 kontrol: üretim/kapı kilidi, fiziksel geçiş, balon bariyeri, sipariş ücreti ve kapasitesi, kargo taşıma/kurulum/iptal, çakışma, cihaz taşıma, tablet sırasında kayıt, oda dağılımı, çizim gruplama, fizik bütçesi, yerçekimi, gösterge zaman penceresi, market değeri, kayıt/yükleme ve yeni oyun temizliği.

Diğer kontroller: `test_visual_package.gd`, `test_contact_and_design.gd`, `test_tablet_shop.gd`. Aynı geçici kullanıcı veri dizini şartı geçerlidir. `test_factory_flow.gd -- --capture` grafik ortamında kapı, kargo ve tablet ekran görüntülerini `/tmp/balloon-room-*.png` dosyalarına yazar.
