# Simple Sale Offline - Loyiha Strukturasi

Ushbu hujjat loyihadagi fayllar va papkalarning vazifalarini tushuntiradi.

## 📁 `lib/` - Asosiy kodlar
Loyiha kodi asosan ushbu papkada joylashgan.

### 🏠 `main.dart`
Ilovaning kirish nuqtasi. Bu yerda `Provider`lar sozlanadi, asosiy tema va router (sahifalar ketma-ketligi) aniqlanadi.

---

### 📂 `lib/models/` - Ma'lumot turlari (Entities)
Dasturda ishlatiladigan barcha ma'lumot tuzilmalari shu yerda saqlanadi.
- **`product.dart`**: Mahsulot modeli (nomi, narxi, shtrix kodi, zaxirasi).
- **`category.dart`**: Mahsulot kategoriyalari.
- **`sale.dart`**: Sotuv amaliyoti ma'lumotlari.
- **`stock_entry.dart`**: Kirim amaliyoti (mahsulotni omborga qo'shish).
- **`stock_transfer.dart`**: Ombordan omborga mahsulot o'tkazish.
- **`write_off.dart`**: Mahsulotni hisobdan chiqarish (spisaniye).
- **`warehouse.dart`**: Omborlar haqida ma'lumot.
- **`user.dart`**: Foydalanuvchi/Xodim ma'lumotlari.
- **`register.dart`**: Kassa (terminal) sozlamalari.

---

### 📂 `lib/providers/` - Holatni boshqarish (State Management)
Ilovaning mantiqiy qismi va ma'lumotlarni ekranlar bo'ylab yangilash.
- **`app_state.dart`**: Ilovaning umumiy holati, ma'lumotlarni yuklash va yangilashning asosiy kontrolleri.
- **`features/`**:
  - **`auth_provider.dart`**: Kirish-chiqish va xavfsizlik.
  - **`inventory_provider.dart`**: Ombor, mahsulotlar va qoldiqlar mantiqi.
  - **`sales_provider.dart`**: Sotuv jarayoni, savatcha (cart) bilan ishlash.
  - **`sync_provider.dart`**: Server bilan ma'lumot almashish (sinxronizatsiya).
  - **`settings_provider.dart`**: Ilova sozlamalari (til, kassa tanlash va h.k.).

---

### 📂 `lib/services/` - Tashqi xizmatlar
Ma'lumotlar bazasi, fayllar va tashqi qurilmalar bilan ishlash.
- **`database_service.dart`**: SQLite (mahalliy baza) bilan ishlash.
- **`sync_service.dart`**: Serverdagi API bilan bog'lanish va ma'lumotlarni yuborish/olish.
- **`print_service.dart`**: Cheklarni va shtrix kodlarni printerga yuborish.
- **`excel_import_service.dart`**: Excel fayllardan mahsulotlarni import qilish va shablonlar yaratish.
- **`system_tray_service.dart`**: Windows/macOS tizim tray'ida (soat oldida) ilovani boshqarish.

---

### 📂 `lib/ui/` - Foydalanuvchi interfeysi (UI)
#### 🖥️ `screens/` - Sahifalar
- **`login_screen.dart`**: Tizimga kirish.
- **`dashboard_screen.dart`**: Asosiy boshqaruv paneli (statistika).
- **`pos_screen.dart`**: Sotuvchi oynasi (Kassa).
- **`stock_entry_screen.dart`**: Kirim qilish oynasi.
- **`inventory_screen.dart`**: Ombor qoldiqlari ro'yxati.
- **`sales_history_screen.dart`**: Sotuvlar tarixi.
- **`settings_screen.dart`**: Ilova va tizim sozlamalari.

#### 🧩 `widgets/` - Komponentlar
- **`pos/`**: Sotuv oynasi uchun maxsus kichik qismlar (savatcha, mahsulot kartochkasi).
- **`app_button.dart`**: Umumiy dizayndagi tugmalar.
- **`custom_app_bar.dart`**: Sahifalar yuqori qismi.

---

### 📂 `lib/core/` - Asosiy sozlamalar
- **`constants/`**: Tizimdagi o'zgarmas qiymatlar (versiya, API manzillar).
- **`theme/`**: Ilovaning ranglari, shriftlari va dizayn qoidalari.
