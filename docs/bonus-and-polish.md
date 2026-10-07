# Patlatma, cihazlar, odalar ve sürpriz balonlar

- İğne temasında kısa el geri tepmesi; standart balonda daha belirgin dönen kauçuk parçaları. Özel bonus balonunda parlak parçalar, halka ve ödül sesi. Aynı anda en fazla 14 patlama efekti korunur.
- Cihazların mevcut şarj/çekiş hareketlerine ek hareketli parçalar; başarılı patlatmada genişleyen kısa halka. Diken hareketindeki önceki animasyon yeni darbede sonlandırılır; üst üste birikmez. Göstergeler 30 Hz ile sınırlıdır.
- Dört oda için farklı renkler ve mimari: atölyede tezgâh/alet panosu, fabrikada üretim kabinleri, hangarda yüksek raflar ve tavan vinci, laboratuvarda ışıklı numune kabinleri. Dekor yoğunluğu oda boyutuna uyar, orta zemin cihazlar için açık kalır. Statik kutular ortak materyallerle MultiMesh olarak birleştirilir.
- Paralar yaklaşık 0,45 saniyelik yay çizerek oyuncuya yaklaşır. Ardışık toplama sesleri yükselir, en yüksek notada kalır. Tek para iki kez ödül veremez. Mevcut 120 fiziksel para ve dört uçan yazı sınırı korunur.

## Sürpriz balonlar

Altın bonus: 10 saniye 2× balon kazancı. Mor bonus: 10 saniye 30 metre para çekimi. Balon işaretlerinde iğneyle patlatılması gerektiği yazar.

Yalnız doğrudan `needle` teması açar. Cihaz, bomba, sıçrama ve diğer zincirler bonusu tetikleyemez. Otomatik iğnenin doğrudan teması geçerlidir. Cihaz verim sayaçları korunan balonları patlatılmış saymaz.

Üretim başladığında ilk 30 saniye bekleme; ardından her üretilen balonda %0,8 şans. Bir sürprizden sonra en az 30 saniye ara. Aynı anda en fazla iki bekleyen sürpriz balon. Aynı bonus yenilenirse süre yeniden 10 saniye olur, çarpan katlanmaz; iki farklı bonus birlikte çalışabilir.

2× kazanç balonun patladığı anda paraya yazılır; yerden toplama sırasında tekrar çarpılmaz. Altın balonun ek ödülüne de uygulanır. Görev, bakım ve diğer sabit ödüller çarpılmaz. Üretim durunca, elektrik kesilince ve oyun duraklayınca bonus süresi bekler. Kalan süre kayıt/yüklemede korunur; yeni oyun ve prestij temizler. Kayıttaki 120 balon sınırında nadir bonuslara öncelik verilir.

## Doğrulama

`tests/test_bonus_and_polish.gd`: 31 kontrol; yalnız iğne koruması, tek ödül, sürelerin bağımsız bitişi, kayıt/yükleme, para yayı, oda kimlikleri ve dekor birleştirme.

Temas, tablet, görev/tesis, fabrika/kargo, boru sınırları ve görsel paket regresyon kontrolleri de çalıştırıldı. Dört oda ve bonus/cihaz ekranı gerçek Vulkan görüntülerinde incelendi. Bu paket için yeni FPS karşılaştırması yapılmadı.
