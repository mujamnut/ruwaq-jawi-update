# Category Arabic Images

Folder ini untuk gambar tulisan Arab bagi setiap kategori dalam Home Screen.

## 📋 **Senarai Gambar Yang Diperlukan:**

1. **fiqh.png** - الفقه
2. **akidah.png** - العقيدة
3. **quran.png** - القران و التفسير
4. **hadith.png** - الحديث
5. **sirah.png** - السيرة
6. **akhlak.png** - التصوف
7. **usul_fiqh.png** - أصول الفقه
8. **bahasa_arab.png** - لغة العربية

---

## 🎨 **Spesifikasi Design:**

### **Format:**
- **File Type:** PNG-24 with alpha channel
- **Background:** **TRANSPARENT** (no background color)

### **Resolution:**
- **Recommended:** **256x256 pixels** atau **512x512 pixels**
- **JANGAN guna 1024px atau lebih besar!** Terlalu besar, akan kelihatan kecil dalam card
- Image akan auto-scale untuk penuhkan space yang ada dalam card
- 256px atau 512px sudah cukup untuk quality yang baik

### **Warna Tulisan:**
- **Text Color:** Hitam (#000000) atau Dark Gray (#1A1A1A)
- App akan automatically apply **green color tint** (`AppTheme.primaryColor`)
- Jadi gambar anda **MESTI hitam/dark gray**, app akan tukar jadi hijau

### **Font Style:**
- **Arabic Font:** Kufic style (traditional, elegant, readable)
- **Contoh font:** Kufi, Naskh, atau Thuluth
- **Weight:** Bold atau SemiBold supaya jelas

### **Layout:**
- **Padding:** Beri margin **minimum 5-8%** dari edge (jangan terlalu banyak padding!)
- **Tulisan:** Buat sebesar mungkin untuk fill space dengan betul
- **Alignment:** Center (horizontal & vertical)
- **Spacing:** Pastikan spacing antara huruf sesuai untuk dibaca
- **Tips:** Tulisan patut ambil ~85-90% dari canvas size untuk nampak besar

---

## ✅ **Checklist Before Export:**

- [ ] Background adalah **transparent** (bukan putih!)
- [ ] Tulisan warna **hitam** atau **dark gray** (bukan hijau!)
- [ ] Resolution **256x256px atau 512x512px** (JANGAN lebih besar!)
- [ ] File format **PNG** (bukan JPG!)
- [ ] Padding **5-8% sahaja** (jangan banyak sangat!)
- [ ] Tulisan **besar** (~85-90% canvas size)
- [ ] Tulisan **centered** dan **clear**
- [ ] File name **exactly match** (contoh: `fiqh.png` bukan `Fiqh.PNG`)

---

## 🖼️ **Contoh Preview:**

Bila gambar di-import ke app:
1. App akan load PNG transparent background
2. Apply **green color filter** (AppTheme.primaryColor)
3. Display dalam gradient green background card
4. Hasilnya: Tulisan Arab hijau yang cantik dan professional!

---

## 🚨 **Important Notes:**

1. **File naming mesti exact!** Case-sensitive: `fiqh.png` bukan `Fiqh.png`
2. **Transparent background wajib!** Kalau ada white background, akan nampak kotak putih
3. **Warna hitam/dark gray sahaja!** App akan auto-tint jadi hijau
4. **Size 256px atau 512px!** JANGAN guna 1024px, akan nampak kecil!
5. **Tulisan kena BESAR!** Fill ~85-90% canvas, padding 5-8% je

---

## 📦 **Selepas Letak Gambar:**

Selepas anda letak semua 8 gambar dalam folder ini:
1. Run `flutter pub get` (untuk refresh assets)
2. Restart app (hot reload mungkin tak cukup)
3. Check Home Screen → bahagian Kategori
4. Gambar akan auto-replace text yang sedia ada

Kalau gambar fail load, app akan **auto-fallback** kepada tulisan Arab text.
