# Görevler, tesis, tek kol ve performans — 28 Eylül 2026

## Uygulananlar

- Görev hedefi son 60 saniyenin patlatma puanı ve ölçülmüş süre üzerinden hesaplanır. İlk saniyelerde oda üretim tahmini kullanılır. Anlık PPS veya ömür boyu toplam kullanılmaz.
- Kombo ardışık gerçek balon temaslarıyla ilerler; 1,5 saniyelik ara seriyi keser. Üretim durdurulduğunda görev zamanı/progresi durur. Görev ve dakika penceresi kayda dahil edilir.
- Tablet Tesis sekmesi: üretim başlat/durdur, ücretsiz yerçekimi ayarı, kargo, görev ve cihazların son 10 saniyelik çıktısı. Kapı/üretim güvenlik kilitleri korunur.
- Sol el ve hava itişi kaldırıldı. Sağ tık cihaz yerleştirmeyi iptal etmeye devam eder. Sağ el, gövdeye bağlı omuz/dirsek ve uzayan mekanik önkolla desteklenir; tablet tek sağ elle tutulur.
- Balon yüzeyinde hedefleme ortak TriangleMesh BVH üzerinden yapılır. Yakın temas geometrisi korunur.
- Balon ve para geometrisine bir kez üretilen, paylaşılan yerleşik LOD seviyeleri eklendi. Uzakta daha az üçgen çizilir.
- Cihaz gösterge materyalleri en fazla 30 Hz yenilenir. Mıknatıs sorguları farklı fizik karelerine dağıtılır; zamanlayıcı artığı korunur.

## Ölçüm

Godot 4.7.2, Forward+, AMD RX 5500 XT, 1280×720, VSync kapalı; `tests/profile_balloon_load.gd`. Her durum 1,5 saniye ısınma + 3,5 saniye örnekleme, 100/380/720 balon, sabit/hareketli. Bunlar ayrı stres sahnesi sonuçlarıdır; bütün oyunun FPS garantisi değildir. Tek kısa ölçüm koşusu nedeniyle özellikle fizik ve uç değerler gürültülüdür.

| Hareketli balon | Önce p95 kare ms | Sonra p95 kare ms | Önce ortalama çizilen primitive | Sonra |
|---|---:|---:|---:|---:|
| 100 | 2,907 | 1,878 | 229.009 | 34.228 |
| 380 | 2,504 | 1,971 | 362.629 | 127.692 |
| 720 | 3,318 | 2,991 | 684.279 | 248.685 |

720 hareketli balonda geometri yaklaşık %64 azaldı. LOD grupları nedeniyle draw-call sayısı yaklaşık 42'den 68'e çıktı; geometri kazancı bu testte daha ağır bastı. 100 sabit balonda p95 1,308 ms'den 1,670 ms'ye çıktı: her durumda iyileşme iddiası yoktur.

`tests/test_surface_queries.gd`: 200 ışında eski üçgen taramasıyla yeni yerleşik sorgu arasında 0,1 mm toleransta sıfır uyuşmazlık. Aynı çalıştırmada toplam süre 24.640 µs → 621 µs; yalnızca sorguda yaklaşık 40 kat hızlanma, toplam oyunda değil.

Başarılı kontroller: görev/tesis 30, fabrika/kargo 48, temas/tasarım 19, tablet 10 ve görsel paket. Gerçek oyun görüntülerinde bekleme, balona uzanma ve tablet pozları incelendi. Testler geçici XDG_DATA_HOME kullanır, oyuncu kayıtlarına dokunmaz.

## Sonraki paket için öneriler — henüz uygulanmadı

1. **Elde basınç tabancası:** Balonları seçilen makineye yönlendirir. İğneden farklı bir kontrol rolü, enerji tüketimi ve kısa bekleme süresi. Sol eli geri getirmez.
2. **Şarjlı elektrikli patlatıcı:** Dar alanda küçük grupları patlatır; şarj süresi ve ısınma sayesinde otomasyonun yerini almaz. Sonrasında zincir etkisi/menzil arasında yükseltme tercihi.
3. **Mıknatıs–cihaz bağlantısı:** Çekilen balonları seçilen patlatıcıya yönlendiren çıkış; yeni cihazın sadece daha yüksek hasar vermek yerine düzen kurmayı sağlaması.
4. **Odayı üretim bölümleriyle büyütme:** Yeni bölüm kendi boru grubu ve cihaz alanıyla açılsın. Mevcut 18→38→65→95 m genişlemede alan, üretim hızından çok daha hızlı büyüyor; boşluk hissinin ana nedeni bu.
5. **Denge:** Üç cihaz türü × en fazla altı adet = 18 cihaz; 24/36 oda kapasitesi mevcut katalogla doldurulamıyor. Oda seviyesine göre satın alma sınırı veya yeni işlevli cihazlar gerekir.
6. **Denge:** Ağırlıklı kapasite ile fiziksel balon bütçesi ayrı: büyük odalarda basınç hedefi doğal olarak daha zor oluşuyor. Oda kapasitesi/boru dağılımı birlikte ayarlanmalı; yalnız balon sayısını artırmak performansı tehlikeye atar.
7. **İlerleme hedefi:** İlk otomasyonun geri ödeme süresi ve sonraki odanın açılma süresi ölçülerek fiyat ayarı yapılmalı. İlk mıknatıs 4.500 puana çekildi. EMP eşiği 25.000 olarak bırakıldı; aradaki ilerleme gerçek oynanışta ölçülmeli.


## Market denge ayarı (30 Eylül 2026)

- Yerçekimi artık beş modlu ücretsiz tesis ayarıdır; eski regülatör kartı gizlenmiştir. Eski kayıtlardaki yerçekimi modu korunur ve mod seçmek para harcatmaz. Duvar terminali ücretsiz sıradaki moda geçer.
- Mıknatısın ilk açılma eşiği 15.000'den 4.500 patlatma puanına alındı; cihaz ve teknoloji kademelerinin erken açılma eşikleri de öne çekildi. Üretim hızı değerleri teorik tavanı bilerek değiştirilmedi: fizik bütçesi ve cihaz çıktısıyla birlikte gerçek oynanışta ölçülmesi gerekir.
- Oda market kartı artık boru sınırını, cihaz yuvasını ve balon kapasitesini beraber gösterir.

## Gerçek patlatma sayımı ve Turbo kaldırılması (1 Ekim 2026)

- Turbo ilerleme ve coin çarpanları kaldırıldı. Her fiziksel patlama toplam hedefe ve PPS/dakika sayaçlarına bir ekler. Balon kademesi coin ödülünde ve değerli balon görevlerinde kullanılır.
- Geçici 2× bonus artık coin ödülünü artırır; toplam patlatmayı artırmaz.
- Görev arz tahmini fiziksel balon adedini kullanır.
- Kayıt sürümü 9: eski kayıtların kazanılmış toplamı, parası ve açılımları korunur. Eski çarpanlı toplamdan gerçek geçmiş adedi hesaplanamaz; bir milyon gerçek patlatmanın baştan ölçülmesi yeni oyun gerektirir. Eski kayıt yüklenirken puan temelli dakika penceresi ve görev sıfırlanır.
- Oda eşikleri, fiyatlar, üretim sınırları ve cihaz görünürlüğü bu değişiklikte yeniden dengelenmedi.
