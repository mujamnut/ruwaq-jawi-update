# 🕌 Maktabah Ruwaq Jawi - Platform Pembelajaran Islam Digital

> **"Menyebarkan ilmu Islam melalui teknologi moden"**

Aplikasi mobile Flutter moden yang menyediakan akses berlangganan kepada kandungan pendidikan Islam (kitab/buku dan video) dengan antara muka yang elegan dan mesra pengguna.

[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev/)
[![Supabase](https://img.shields.io/badge/Supabase-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)](https://supabase.com/)
[![License](https://img.shields.io/badge/License-Proprietary-red?style=for-the-badge)](LICENSE)

## ✨ Fitur Utama

📚 **Pustaka Digital Islam** - Akses kepada koleksi kitab klasik dan moden dengan PDF viewer interaktif

🎥 **Kuliah Video Bersepadu** - Sambungan YouTube langsung untuk kuliah dan pengajian Islam

🔐 **Sistem Langganan** - Model premium untuk kandungan eksklusif dengan pembayaran selamat

📱 **Dual Interface** - Antara muka berasingan untuk pelajar dan pentadbir

🎨 **Shadcn UI Design** - Rekaan moden dengan animasi halus dan responsif

🌙 **Tema Adaptif** - Dark mode automatik untuk keselesaan membaca

## 🏗 Teknologi Stack

| Komponen | Teknologi | Deskripsi |
|----------|-----------|-----------|
| **Frontend** | ![Flutter](https://img.shields.io/badge/Flutter-02569B?style=flat&logo=flutter) | Framework mobile cross-platform |
| **Backend** | ![Supabase](https://img.shields.io/badge/Supabase-3ECF8E?style=flat&logo=supabase) | Auth, Database, Storage, Edge Functions |
| **UI Design** | Shadcn Flutter | Komponen UI moden dan konsisten |
| **Icons** | Phosphor & Huge Icons | Ikon solid dan stroke yang konsisten |
| **Payment** | ToyyibPay | Gateway pembayaran Malaysia |
| **State Management** | Provider | State management pattern |
| **Navigation** | Go Router | Routing dan navigation |
| **Storage** | Hive | Local data persistence |

## 🚀 Quick Start

### 📋 Prerequisites
```bash
# Versi minimum yang diperlukan
Flutter SDK: 3.24.0+
Dart SDK: 3.5.0+
Android Studio / VS Code
Git version control
```

### ⚡ Installation

1. **Clone Repository**
   ```bash
   git clone https://github.com/mujamnut/ruwaq-jawi-update.git
   cd ruwaq-jawi-update/ruwaq_jawi
   ```

2. **Setup Flutter**
   ```bash
   # Install dependencies
   flutter pub get

   # Check environment
   flutter doctor

   # Run analysis
   flutter analyze
   ```

3. **Environment Configuration**
   ```bash
   # Copy environment template
   cp lib/core/config/env_config.dart.example lib/core/config/env_config.dart
   # Edit with your Supabase credentials
   ```

4. **Run Application**
   ```bash
   # Development mode
   flutter run -t lib/main_development.dart --debug

   # Production build
   flutter build apk --release
   flutter build ios --release
   ```

### 🔧 Environment Setup
```bash
# Supabase Configuration
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_supabase_anon_key
SUPABASE_SERVICE_KEY=your_supabase_service_key

# Payment Configuration
TOYYIBPAY_SECRET_KEY=your_toyyibpay_key
TOYYIBPAY_CATEGORY_CODE=your_category_code
```

## 📂 Struktur Projek

```
ruwaq_jawi/
├── 📱 lib/
│   ├── 🎨 core/
│   │   ├── config/           # Environment & app configuration
│   │   ├── constants/        # App constants & colors
│   │   ├── services/         # API services & providers
│   │   ├── theme/           # Shadcn UI theme & styling
│   │   ├── utils/           # Helpers & utilities
│   │   └── widgets/         # Reusable UI components
│   ├── 👨‍🎓 features/
│   │   ├── student/         # Student interface & screens
│   │   └── admin/           # Admin interface & screens
│   └── 🚀 main*.dart        # Entry points (dev/prod)
├── 📊 database/              # Supabase migrations & SQL
├── 🖼️ assets/               # Images, icons, fonts
├── 🛠️ android/ & ios/        # Platform configurations
└── 📋 pubspec.yaml          # Dependencies & metadata
```

## 🎨 Design System

### 🎯 Theme Guidelines
- **Style**: Shadcn UI + Material Design 3
- **Icons**: Phosphor (solid) & Huge Icons (stroke rounded)
- **Colors**: Islamic-inspired palette with 60-30-10 rule
- **Animations**: Smooth & responsive transitions
- **Rounded Corners**: Context-based (xl for primary, md for secondary)

### 🎨 Color Palette
```dart
// Primary Colors
primary: Color(0xFF1B4332),      // Deep Islamic Green
secondary: Color(0xFFD4AF37),    // Gold Accent
accent: Color(0xFF00BF6D),       // Emerald Green

// Neutral Colors
background: Color(0xFFF8F9FA),   // Light Background
surface: Color(0xFFFFFFFF),      // White Surface
card: Color(0xFFFFFFFF),         // Clean White Cards
textPrimary: Color(0xFF212529),  // Dark Text
textSecondary: Color(0xFF6C757D) // Gray Text
```

## 📊 Development Progress

### ✅ **Completed Features**
- [x] **Core Architecture** - Flutter project setup with clean architecture
- [x] **UI Design System** - Shadcn components with Islamic styling
- [x] **Authentication** - Supabase Auth integration
- [x] **Database Schema** - Complete tables & RLS policies
- [x] **Student Interface** - Home, kitab, video, profile screens
- [x] **Admin Interface** - Dashboard, content management, analytics
- [x] **Payment System** - ToyyibPay integration & subscription
- [x] **Media Integration** - YouTube API & PDF viewer
- [x] **Notification System** - Real-time alerts & announcements

### 🚧 **In Development**
- [ ] **Performance Optimization** - Image caching & lazy loading
- [ ] **Offline Mode** - Content sync & local storage
- [ ] **Analytics Dashboard** - Advanced user insights
- [ ] **Arabic Language Support** - RTL text & localization

### 🔮 **Planned Features**
- [ ] **Audio Player** - Quran recitation & lectures
- [ ] **Social Features** - Study groups & discussions
- [ ] **Progress Tracking** - Learning analytics & certificates
- [ ] **Web Dashboard** - Admin panel for desktop

## 🛠️ Development Workflow

### 📋 Quality Checks
```bash
# Run analysis before commits
flutter analyze

# Format code
dart format .

# Run tests
flutter test

# Build verification
flutter build apk --debug
```

### 🚀 Build & Deployment
```bash
# Android APK
flutter build apk --release --target-platform android-arm64

# iOS IPA
flutter build ios --release

# Web Build (Future)
flutter build web
```

## 📚 Dokumentasi

| Dokumen | Deskripsi |
|---------|-----------|
| [CLAUDE.md](CLAUDE.md) | 📖 Guidelines pengembangan |
| [PREVIEW_SYSTEM_FIXES_SUMMARY.md](PREVIEW_SYSTEM_FIXES_SUMMARY.md) | 🔧 Summary sistem preview |
| [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md) | 📋 Panduan migration database |
| [NOTIFICATION_IMPROVEMENTS.md](NOTIFICATION_IMPROVEMENTS.md) | 🔔 Improvements sistem notifikasi |

## 🤝 Cara Kontribusi

1. **Fork** repository ini
2. **Create branch** feature (`git checkout -b feature/AmazingFeature`)
3. **Commit** perubahan anda (`git commit -m 'Add some AmazingFeature'`)
4. **Push** ke branch (`git push origin feature/AmazingFeature`)
5. **Open Pull Request**

### 📝 Code Style
- Follow **Shadcn UI** conventions
- Gunakan **Phosphor icons** (solid) untuk primary actions
- Gunakan **Huge Icons** (stroke rounded) untuk secondary elements
- Apply **60-30-10 color rule** untuk design balance
- Responsive design dengan **proper rounded corners**

### 🕌 Etika Islam
- Pastikan semua konten mematuhi nilai-nilai Islam
- Gunakan bahasa yang sopan dan profesional
- Hormati hak cipta dan intelektual
- Prioritaskan user experience untuk pelajar Islam

## 🐞 Troubleshooting

### Isu Common
```bash
# Flutter doctor issues
flutter doctor -v

# Clean build
flutter clean && flutter pub get

# Android build issues
flutter build apk --verbose

# iOS build issues
flutter build ios --verbose
```

## 📞 Support & Contact

- **Project Maintainer**: [Your Name]
- **Email**: [your.email@example.com]
- **Issues**: [GitHub Issues](https://github.com/mujamnut/ruwaq-jawi-update/issues)
- **Documentation**: [Wiki](https://github.com/mujamnut/ruwaq-jawi-update/wiki)

## 📄 Lisensi

🚫 **Proprietary & Confidential**

Hak cipta © 2025 Maktabah Ruwaq Jawi.
Tidak dibenarkan untuk penggunaan komersial tanpa kebenaran bertulis.

---

<div align="center">

**🕌 Maktabah Ruwaq Jawi - Platform Pembelajaran Islam Digital**

*"Menyebarkan ilmu Islam melalui teknologi moden"*

[![GitHub stars](https://img.shields.io/github/stars/mujamnut/ruwaq-jawi-update?style=social)](https://github.com/mujamnut/ruwaq-jawi-update/stargazers)
[![GitHub forks](https://img.shields.io/github/forks/mujamnut/ruwaq-jawi-update?style=social)](https://github.com/mujamnut/ruwaq-jawi-update/network)

**Last Updated**: October 2025
**Version**: 1.0.0
**Status**: Production Ready ✅

</div>
