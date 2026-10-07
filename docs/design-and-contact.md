# Oda, koleksiyon nesneleri ve el etkileşimi

- Dört oda ölçeğinde çevre modülleri: tezgâh, dolap, kontrol ekranı, basınç paneli, servis şeridi ve büyük odalarda tavan taşıyıcıları. Tezgâh ve dolapların çarpışması vardır; merkez cihaz yerleşimine açıktır.
- Balonların ortak, boynu daralan gövde geometrisi; bomba fitili, altın halkası ve hava bantları. Paralar ortak kabartmalı ve tırtıklı geometri kullanır.
- İğne, kamera rayının görünür balon yüzeyiyle kesişimine hizalanır. İğne ucunun yerel ofseti hesaba katılır; hareketli hedef takip edilir ve patlama temas callback'inde gerçekleşir. Fizik simülasyonu mevcut küreleri kullanmaya devam eder.
- Sağ tık: sol bilekteki hava aparatıyla yönlü itiş. Parmaklar açılır, darbe animasyonla eşzamanlı çıkar. 14 enerji, 0.35 saniye bekleme; duvar arkası ve oyuncunun arkası etkilenmez.
- Menü açılması/cihaz taşıma bekleyen el eylemlerini iptal eder. Aynı animasyonun hem sinyalden hem doğrudan çağrıdan iki kez başlatılması kaldırılmıştır.
- Balon darbe esnemesi artık tier ölçeğini ikinci kez uygulamaz.

## Doğrulama

Proje dizininden, oyuncu kayıtlarından ayrı veri alanıyla:

```bash
XDG_DATA_HOME=/tmp/balloon-room-visual-tests godot --headless --path . --script tests/test_visual_package.gd
XDG_DATA_HOME=/tmp/balloon-room-contact-tests godot --headless --path . --script tests/test_contact_and_design.gd
```

İkinci komutta `--headless` kaldırılıp sonuna `-- --capture` eklenirse `/tmp/balloon-room-design-*.png` görsel kontrol çıktıları oluşur. Test sahnesi nesneleri karşılaştırmak için sabit tutar; normal oyunda fizik hareketi devam eder.
