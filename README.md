# B2B Toptancım Projesi

Bu proje, toptancılar ve perakendeciler arasında B2B (Business to Business) ticaret yapılmasını sağlayan bir mobil ve web uygulamasıdır. 

## 🚀 Teknolojiler

### Frontend
- **Flutter** - Cross-platform mobil ve web uygulaması 
- **Provider** - State management 
- **HTTP** - API iletişimi 
- **Shared Preferences** - Local storage 

### Backend
- **Node.js** - Server-side JavaScript runtime 
- **Express.js** - Web framework 
- **PostgreSQL** - Veritabanı 
- **JWT** - Authentication 
- **bcryptjs** - Şifre hashleme 
- **CORS** - Cross-origin resource sharing 

## 🏗️ Frontend Mimarisi: Bileşen Tabanlı Yaklaşım

Projenin frontend kısmı, yeniden kullanılabilir ve bağımsız bileşenlere (widget'lara) dayalı modüler bir mimari ile geliştirilmektedir. Bu yaklaşım, kod tekrarını azaltır, tutarlı bir kullanıcı deneyimi sağlar ve bakım süreçlerini basitleştirir.

**Temel Felsefe: Sorumlulukların Ayrılması**

- **Ekranlar (`lib/screens/`):** Birer "orkestratör" olarak görev yaparlar. Ekranlar, state yönetimi (Provider'lar aracılığıyla veri çekme), iş mantığı ve sayfa yerleşiminden sorumludur. UI'ı oluşturmak için `lib/widgets/` klasöründeki bileşenleri bir araya getirirler.

- **Bileşenler (`lib/widgets/`):** Uygulamanın "görsel tuğlalarıdır". Bu widget'lar, kendilerine parametre olarak verilen veriyi nasıl göstereceklerini bilirler. Kullanıcı etkileşimlerini (tıklama, form girişi vb.) callback fonksiyonları (`onTap`, `onPressed`) aracılığıyla üst katman olan ekranlara iletirler. İş mantığı içermezler ve doğrudan servisleri çağırmazlar.

**Örnek Uygulama:**
Finansal işlemlerin listelendiği `FinancialTransactionsScreen` ekranını ele alalım. Bu ekrandaki her bir işlem kartı, `lib/widgets/financial_transaction_card.dart` adında ayrı bir widget olarak tasarlanmıştır. Bu kart, bir `FinancialTransaction` nesnesi ve `onTap` gibi fonksiyonları parametre olarak alır. Bu sayede, aynı `FinancialTransactionCard` widget'ı, farklı ekranlarda (örneğin bir müşteri profilindeki işlem geçmişi) mantık tekrarı olmadan kolayca kullanılabilir.

## 📁 Proje Yapısı