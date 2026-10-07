> Arşiv: Bu rapor eski oda düzenine aittir. Güncel üç odalı akış için [oda ilerleyişi](room-progression.md) belgesini kullanın.

# Kısa denemelerle denge ölçümü

F1 paneli gerçek oturumun dakika kayıtlarını, satın alma zamanlarını, son 10 saniye üretimini, fizik bütçesini ve patlatma hızını gösterir. Yeni **Oda Dengesi** kartı son beş dakikaya kadar gerçek oynanıştan oda hedefi ETA'sı, patlatma/üretim farkı, toplanan coin/patlatma ve olası darboğazı hesaplar. İğne, dart ve patlatan cihazların çıktısı ayrı sayılır. En az on saniye aktif kullanımla silah başına patlatma/sn, en az on atışla dartın isabetli atış oranı görünür. `~/Desktop/veri.txt` dosyasına da JSON olarak yazılır. Bu, **ne olduğunu** gösterir; yeni fiyat ve eşiklerle gelecekte ne olacağını tek başına hesaplamaz. Oyuncu denemesi olmadan hedef alma, cihaz yerleşimi ve fizik sıkışması güvenilir biçimde kestirilemez.

İki araç eklendi:

```sh
XDG_DATA_HOME=/tmp/balloon-room-progression-tests godot --headless --path . --script res://tests/simulate_progression.gd
python3 tools/analyze_balance.py ~/Desktop/veri.txt
```

İlk komut `ShopManager` içindeki **güncel** oda, boru, dökülme, eşik ve fiyat kataloglarından üç senaryo hesaplar. Gelen balonların %50 / %70 / %90'ının patladığını, kazanılan coinlerin %70'inin toplandığını ve toplanan coinin %70'inin üretim geliştirmelerine ayrıldığını varsayar. Balon kademelerinin beklenen coin ödülü oda kataloğundan hesaplanır. Boru ve dökülme geliştirmelerini karşılanabilir seçenekler arasındaki ek üretim/fiyat oranına göre alır. Her oda eşiğinin dakikasını ve satın almanın açılma eşiğinden ne kadar sonra yapıldığını raporlar. Cihazların fiziksel davranışı, silah isabeti, üretim durması ve görev ödülleri bu hesapta **yoktur**. Ayrılan %30 coin diğer alımlar için ayrılmış varsayımsal bütçedir; cihaz verimi ayrıca patlatma oranına yansıtılmalıdır.

1 Ekim kataloğuyla ilk sonuç:

| Patlatılan üretim oranı | Oda 2 açılışı | Hangar açılışı | Oda 4 açılışı | 1 milyon |
|---:|---:|---:|---:|---:|
| %50 | 23,7 dk | 63,0 dk | 112,4 dk | 146,6 dk |
| %70 | 16,9 dk | 45,0 dk | 80,3 dk | 104,7 dk |
| %90 | 13,2 dk | 35,0 dk | 62,5 dk | 81,5 dk |

Bu sonuçlar bir saatlik bitişi doğrulamaz. Ayrıca son odada yüksek verim senaryosu 720 fiziksel balon bütçesiyle sınırlanabilir; model bunu hesaplamaz. Uzun açılma→satın alma aralıkları fiyatların ağır olabileceğine işaret eder, fakat gerçek coin toplama oranıyla kontrol edilmelidir.

İkinci komut F1'in **gerçek** dakika kayıtlarını okur: dakika başına patlatma ve üretim, nominal üretim farkı, fizik bütçesi doluluğu, harcamaları hesaba katan toplanmış coin/patlatma ve mevcut hız devam ederse bir sonraki oda eşiğine kalan yaklaşık süre. Son birkaç dakikayı kullanır; yeni geliştirme sonrası geleceği bilmez. Şu andaki `veri.txt` dosyasında sıfır dakikalık test verisi bulunduğundan henüz gerçek bir tahmin veremiyor.

Pratik ölçüm: yeni oyunda 5–10 dakika normal oynanış, F1 verisini inceleme, yalnız belirlenen darboğazı değiştirme ve aynı bölümü tekrar ölçme. Oda 2'ye geçince aynı işlemi 5.000→60.000 aralığında yapma. Tam 30–60 dakikalık koşu son doğrulama için gerekir; her fiyat değişikliğinde gerekmez.
