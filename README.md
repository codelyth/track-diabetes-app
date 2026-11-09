# Şeker Takibi Uygulaması

Flutter ile geliştirilen, Android için kişisel diyabet takip uygulaması. Diyabetli kullanıcıların kan şekeri ölçümlerini, insülin uygulamalarını ve laboratuvar HbA1c sonuçlarını tek yerde takip etmesini kolaylaştırmayı amaçlar.

> **Durum:** Erken geliştirme aşamasında. Flutter projesi Android emülatöründe çalıştırıldı. Tema ve giriş ekranının ilk kodları hazırlandı; uygulamaya aktarılması ve doğrulanması devam ediyor. Firebase, veri kayıtları, bildirimler ve widget henüz entegre edilmedi.

## Proje hedefleri

- Basit, Türkçe ve kullanıcı dostu arayüz.
- Açlık ve tokluk ölçümlerini ayrı takip etme.
- Kullanıcının belirlediği zamanlarda ölçüm ve insülin kaydı hatırlatmaları.
- Ana ekran widget’ından kayıtlara hızlı erişim.
- Samsung Galaxy A36 üzerinde gerçek cihaz testleriyle doğrulama.

## Planlanan Özellikler

### Kan şekeri kayıtları

- Açlık veya tokluk türü, mg/dL değeri, tarih, saat ve isteğe bağlı not.
- Gün içinde her iki türden de istenildiği kadar kayıt.
- Kayıt ekleme, düzenleme ve silme.
- Tarih, saat, tür ve değer sütunlarından oluşan ölçüm tablosu.
- Bugün, son 7 gün, son 30 gün ve özel tarih aralığı filtreleri.
- Açlık, tokluk ve tüm kayıtlar için tür filtresi.

### Dashboard

- Son kaydedilen ölçüm ve ölçüm zamanı.
- Günlük, haftalık ve aylık özetler.
- Açlık ve tokluk için ayrı ortalamalar ve kayıt sayıları.
- Seçilen filtrelerle tutarlı özetler, grafik ve kayıtlar.
- Son laboratuvar HbA1c sonucu ve test tarihi.
- Günün insülin kayıtları ve sıradaki hatırlatıcı.

Ortalamalar yalnızca girilen ölçümlerin aritmetik ortalamasıdır. Kayıt bulunmayan dönemlerde sıfır yerine boş durum gösterilir.

### İnsülin takibi

- İnsülin adı/türü, uygulanan doz, uygulama zamanı ve not.
- Planlanan uygulamalar için “Henüz kaydedilmedi”, “Yapıldı” ve “Atlandı” durumları.
- Planlanan uygulama ile gerçekleşen enjeksiyon kaydının ayrılması.
- Kullanıcı onayı olmadan uygulamaların yapılmış sayılmaması.

### HbA1c

- Laboratuvar sonucu ve test tarihi ekleme.
- Sonuç geçmişi, düzenleme ve silme.
- Türkçe ondalık virgül desteği.
- HbA1c sonuçlarının kan şekeri ortalamalarından ayrı tutulması.

### Hatırlatıcılar ve widget

- Açlık, tokluk ve insülin kaydı için bağımsız hatırlatıcılar.
- Aynı gün için birden fazla saat ve tekrar günü seçimi.
- Bildirimden kayıt ekranına geçiş ve erteleme.
- Kompakt ve geniş Android ana ekran widget’ları.
- Widget üzerinde son ölçüm, kayıt zamanı ve hızlı ölçüm ekleme.
- Geniş widget üzerinde sıradaki hatırlatıcı.
- Widget’ta ölçüm değerini gizleme tercihi.

### Hesap ve veri yönetimi

- Firebase Authentication ile e-posta/şifre girişi.
- Hesap oluşturma, şifre sıfırlama ve çıkış.
- Cloud Firestore ile kullanıcıya ait kayıtların saklanması.
- Kullanıcı verilerini ayıran erişim kuralları.
- Bağlantı ve senkronizasyon durumlarının açıkça gösterilmesi.

## Temel davranış kuralları

- Ölçüm türü saatten tahmin edilmez; kullanıcı tarafından seçilir.
- Ölçüm eklemek için hatırlatıcı oluşturulmuş olması gerekmez.
- Bildirimi kapatmak veya ertelemek, ölçüm ya da enjeksiyon yapıldığı anlamına gelmez.
- Kayıt eksikliği otomatik olarak “Atlandı” şeklinde yorumlanmaz.
- Son ölçüm her zaman tarih ve saatiyle gösterilir; canlı değer gibi sunulmaz.
- Bildirimlerin görünmesi Android izinleri ve cihaz ayarlarına bağlıdır.

## Teknolojiler

| Teknoloji | Kullanım | Durum |
| --- | --- | --- |
| Flutter / Dart | Mobil uygulama | Kullanılıyor |
| Material 3 | Arayüz bileşenleri | İlk tema kodları hazır |
| Firebase Authentication | Kimlik doğrulama | Planlandı |
| Cloud Firestore | Veri saklama | Planlandı |
| Android yerel bildirimleri | Hatırlatıcılar | Planlandı |
| Android App Widget | Ana ekran widget’ı | Planlandı |

Bildirim, grafik, durum yönetimi ve widget paketleri geliştirme sırasında seçilecektir.

## Tasarım

Arayüz, Stitch ile hazırlanan ekran tasarımlarını referans alır:

- Mor/lila renk paleti ve açık arka plan.
- Yuvarlak kartlar, belirgin işlem düğmeleri ve okunaklı alanlar.
- Alt menü: **Özet · Kayıtlar · Hatırlatıcılar · Ayarlar**.
- Farklı ekran boyutlarına ve klavye açılmasına uyumlu yerleşim.

Eksik ekranlar ve etkileşim durumları aynı tasarım diliyle tamamlanacaktır.

## Geliştirme ortamı

İlk çalıştırmada kullanılan ortam:

- Flutter 3.47.9
- Dart 3.13.7
- Windows 11
- Android Studio ve Android SDK
- Android 15 / API 35 Google APIs x86_64 emülatörü

Test profili: 6,7 inç, 1080 × 2340 çözünürlük, 3072 MB RAM. Bu profil Galaxy A36 ekranına yaklaşmak içindir; Samsung One UI davranışını birebir taklit etmez.

## Kurulum ve çalıştırma

1. Depoyu klonlayın ve proje kök dizinini açın.
2. Flutter ve Android ortamını kontrol edin:

```bash
flutter doctor
```

3. Bağımlılıkları indirin:

```bash
flutter pub get
```

4. Android emülatörünü başlatın veya USB hata ayıklaması açık bir Android cihaz bağlayın:

```bash
flutter devices
```

5. Uygulamayı çalıştırın:

```bash
flutter run -d <device-id>
```

Cihaz kimliği, `flutter devices` çıktısındaki değer olmalıdır.

Firebase henüz entegre edilmediği için mevcut başlangıç sürümünde Firebase kurulumu gerekmez. Entegrasyon tamamlandığında yapılandırma adımları eklenecektir.

## İlk arayüz için önerilen yapı

Aşağıdaki yapı, tema ve giriş ekranı için hazırlanan ilk kodların hedef düzenidir:

```text
lib/
  main.dart
  app.dart
  core/
    theme/
      app_theme.dart
  features/
    auth/
      presentation/
        login_screen.dart
```

Yeni özellikler geliştikçe ilgili modeller, veri erişimi ve ekranlar kendi özellik klasörleri altında eklenecektir.

## Yol haritası

- [x] Flutter ve Android geliştirme ortamının kurulması
- [x] Boş Flutter projesinin Android emülatöründe çalıştırılması
- [x] Stitch ekran tasarımlarının hazırlanması
- [x] Ortak tema ve giriş ekranının uygulanıp doğrulanması
- [ ] Kayıt ve şifre sıfırlama ekranları
- [x] Firebase Authentication entegrasyonu
- [x] Firestore veri modeli ve erişim kuralları
- [x] Kan şekeri kayıtları ve filtreli tablo
- [x] Dashboard, ortalamalar ve grafik
- [x] İnsülin uygulama takibi
- [x] HbA1c kayıtları
- [ ] Yerel hatırlatıcılar ve bildirim izinleri
- [ ] Android ana ekran widget’ları
- [ ] Ayarlar ve profil
- [ ] Galaxy A36 üzerinde bildirim, widget ve günlük kullanım testleri

## Veri gizliliği

Gerçek sağlık verileri, kullanıcı şifreleri, servis hesabı anahtarları ve imzalama anahtarları depoya eklenmemelidir. Örnek veriler kurgusal olmalıdır.

Firebase erişim kuralları ve kimlik doğrulama kontrolleri, gerçek kullanıcı verileriyle kullanımdan önce uygulanıp test edilecektir. Uçtan uca şifreleme bu projenin mevcut bir özelliği değildir.

## Kullanım kapsamı

Uygulama manuel kayıt ve hatırlatma amacıyla geliştirilmektedir. Sürekli glikoz izleme sistemi değildir; insülin dozu hesaplamaz ve tedavi önerisi üretmez. HbA1c alanı kullanıcı tarafından girilen laboratuvar sonuçlarını saklar.

## Geliştirici

Yaprak Cihantimur

