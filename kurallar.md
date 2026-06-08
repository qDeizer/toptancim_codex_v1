Kodlama için kurallar:
{
Clean Code İlkeleri
Anlamlı İsimler Kullan: Değişken, fonksiyon, sınıf isimleri anlaşılır olmalı.
Kısa ve Tek Amaçlı Fonksiyonlar: Her fonksiyon tek bir işi yapmalı.
Yorum Yerine Anlaşılır Kod: Yorum satırları yerine okunabilir isimlendirme tercih edilmeli.
Tekrarı Önle (DRY - Don’t Repeat Yourself): Aynı kod parçaları tekrar edilmemeli.
Kodun Okunabilirliği: Kod, sadece makine için değil insanlar için de yazılmalı.
Basitliği Koru (KISS - Keep It Simple, Stupid): Gereksiz karmaşıklıktan kaçınılmalı.
Test Edilebilir Kod Yaz: Kod birim testlerine uygun tasarlanmalı.
Bağımlılıkları Azalt: Modüller arası bağımlılık minimumda tutulmalı.

SOLID İlkeleri
S - Single Responsibility Principle (Tek Sorumluluk İlkesi): Her sınıf/fonksiyon sadece bir iş yapmalı.
O - Open/Closed Principle (Açık/Kapalı İlkesi): Kod, genişletmeye açık ama değiştirmeye kapalı olmalı.
L - Liskov Substitution Principle (Yerine Geçme İlkesi): Türeyen sınıflar, türediği sınıfın yerine sorunsuzca kullanılabilmeli.
I - Interface Segregation Principle (Arayüz Ayrımı İlkesi): Kullanılmayan metodlarla şişkin arayüzlerden kaçınılmalı.
D - Dependency Inversion Principle (Bağımlılıkların Ters Çevrilmesi İlkesi): Yüksek seviye modüller, düşük seviye modüllere doğrudan bağımlı olmamalı; soyutlamalara bağlı olmalı.

AI Özelinde Uygulama Önerileri
Model Sarmalayıcı (Wrapper) Sınıflar: AI modelini doğrudan kullanmak yerine, sarmalayıcı sınıf ile erişim.
Veri İşleme Katmanı: Veri temizleme, dönüştürme işlemleri ayrı sınıf/fonksiyonlarda tutulmalı.
Pipeline Tasarımı: Eğitim, validasyon, test adımları ayrı ve tek sorumluluk prensibine uygun olmalı.
Bağımlılık Yönetimi: Model, veri seti veya kütüphane değişse bile ana kod etkilenmemeli.
Konfigürasyon Yönetimi: Parametreler sabit kodlanmamalı, konfigürasyon dosyaları veya environment variable kullanılmalı.
}

oluşturulacak proje için kurallar:
{

## 1. Sahip Olması Gereken Kurallar

- **Temiz Kod ve SOLID Prensipleri**
Yazılım; bakımı kolay, modüler, okunabilir ve tekrar kullanılabilir kod yapısına sahip olmalı.
    - *Single Responsibility Principle*: Her sınıf/servis tek bir işi yapmalı.
    - *Open/Closed Principle*: Yeni özellikler kolay eklenebilmeli, mevcut kod minimum değişmeli.
        - *Dependency Inversion*: Bağımlılıklar soyutlamalar üzerinden olmalı.
- **Test Edilebilirlik**
Birim testleri, entegrasyon testleri ve uçtan uca testler yapılabilir şekilde tasarlanmalı.
- **Standartlara Uygunluk**
Kodlama standartları (örn. PSR, PEP8, Clean Code) ve endüstri standartlarına (ISO, IEC, OWASP güvenlik standartları) uyulmalı.
- **Sürdürülebilirlik ve Dokümantasyon**
Yazılım mimarisi, API dokümantasyonu ve kullanıcı kılavuzları düzenli şekilde tutulmalı.
- **Güvenlik Kuralları**
Veri şifreleme, erişim kontrolü, loglama ve güvenlik açıklarına karşı (SQL Injection, XSS vb.) koruma sağlanmalı.

---

## 2. Barındırması Gereken Özellikler

- **Performans ve Ölçeklenebilirlik**
    - Yüksek kullanıcı trafiğini kaldırabilmeli.
    - Gerektiğinde yatay ve dikey olarak ölçeklenebilmeli.
- **Hata Yönetimi ve Dayanıklılık**
    - Hata durumlarında sistem çökmeden devam etmeli.
    - Otomatik loglama, hata raporlama ve geri alma mekanizmaları olmalı.
- **Esneklik ve Modülerlik**
Yeni özelliklerin kolay eklenebilmesi için mikro servis veya modüler yapı tercih edilmeli.
- **Kullanıcı Deneyimi (UX/UI)**
Basit, anlaşılır, hızlı ve sezgisel arayüzler barındırmalı.
- **Otomasyon ve Entegrasyon**
    - API desteği olmalı.
    - Diğer yazılım ve sistemlerle kolay entegrasyon sağlamalı.
- **Versiyonlama ve DevOps Uyumlu Yapı**
    - CI/CD pipeline desteği.
    - Otomatik deploy, rollback ve izleme sistemleri.
- **Güncellenebilirlik ve Geriye Dönük Uyum**
Güncellemeler kolay yapılmalı, eski sistemlerle uyum korunmalı.
- **Veri Yönetimi**
    - Yedekleme, geri yükleme ve veri bütünlüğü kontrolü.
    - Büyük verilerle çalışabilme kapasitesi.

}

Bu projeyi yeniden yazacağım. çünkü bu projenin artık optimal ve tutarlı bir kod olduğunu düşünmüyorum ve bu projeyi yeniden yazacağım. senden isteğim bu projeyi yeniden yazman.

1-İlk olarak Mevcut projeyi iyice bir incele projenin özellikleri, ince ayrıntıları neler iyice tanı.
2- Projede olmayan ama eklemek istediğim özellikler var :
{
•Harici dahili kullanıcı birleştirme.
•bildirimler sekmesi olacak, onaylar, yapılan işlemler, genel karışıklı onaylar vb. her şey burada olacak genel mesajlar yayınlanacak.
•finansal işlem oluşturma- silme - düzenleme, sipariş sepet onayı gibi karşılıklı olan bütün işlemlerde karşılıklı onay olacak. kullanıcı bizim oluşturduğumuz harici bir kullanıcı ise gerek olmayacak.
•fatura oluşturma olacak
•Pdf oluşturma: faturların, aylık  ekstrelerin, kullanıcı ile olan işemlerin vb her şeyi pdf si oluşturulabilecek. indirilip, paylaşılabilecek.
• sepet ve alışveriş geçmişi profesyonel e ticaret sistemlerindeki gibi olacak
• stokta olmayan ürünleri talep etme: stoğu bitmiş ürünleri talep etme
•Rol: ileride uygulamayı deploy ettikten sonra kullanıcıların bazı özelliklere erişebilmesi için ücret karşılığında uygulamanın bazı özelliklerini kullanabilmesini sağlayacağım. şimdilik sadece şu şu 4 rol olsun: Müşteri, sadece kendi toptancısı ile finansal işlem yapabilir, ekstre gelir gider vs ekleyemez.
müşteri+: gelir giderlerini kendi finansal işlemlerini de yürütebilir ve bunların analizini raporlarını edinebilir.
toptancı: ürün ekleyebilir markete sunabilir, bağlantı kurulabilir, finansal işlemlerinin analizi raporu yapılabilir.
toptancı+: finansal işlemlerinin yanı sıra ürünlerle alakalı analiz yapabilir, işte hangi müşteriye en çok hangi ürün satılmış, en çok satılan ürünlerim neler, vb ticari anlamda çok geniş kapsamlı analizlerin yapılabildiği bir rol.
•Herhangi bir kişiye yaklaşan borçlarımızı hatırlatma oluşturma, ve bunu görüntüleyebilme.
•topancının belirli etikette ki insanları listeleyip kim ne istemiş, ben bu gün arabama hangi malları yükleyeceğim, hangi mal hangi rafta, kimden ne kadar tahmini tahsilat yapacağım vb. her şeyin toptancı için sunulduğu ekran.
• toptancı bazı ürünlerle etkileşim için kamerasında ki karekod, barkod gibi bir şey ile ürününü tarayıp o ürünü hızlıca seçebilecek
•Proje mobil(ios, android, andorid tablet), mobil web, masaüstü web için uyumlu olacak her platform için ux yeterli seviyede olacak.
}
3-projedeki mevcut özellikleri(ilk maddedeki) üzerinde istediğim özellikleri ekleyerek. ve eksik gördüğün yada düzenleme olması gerektiğini düşündüğün özellikleri de analiz ettikten sonra gereksinimleri ve yapılacakları en ufak mantığına kadar belirlemen belirlemen.
4- projeyi yukarıdaki özellikler ile oluşturmaya başla tercih olarak flutter, node.js, postgresql, jwt token gibi şeyler düşünüyorum ancak saha iyi alternatifler olabileceği tepit edilirse ona yönelinsin