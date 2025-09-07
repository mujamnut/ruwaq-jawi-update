# Maktabah - Islamic Educational Content Platform

A Flutter-based mobile application providing subscription-based access to Islamic educational content (kitab/books and videos).

## 📱 Project Overview

**Maktabah** is a comprehensive Islamic educational platform that offers:
- Digital access to Islamic books (kitab) with PDF viewing
- Synchronized video lectures via YouTube integration
- Subscription-based content unlock system
- Separate interfaces for students and administrators
- Multi-platform support (iOS & Android)

## 🏗 Architecture

- **Frontend**: Flutter with Material Design 3
- **Backend**: Supabase (Auth, Database, Storage, Edge Functions)
- **Payment**: Chip by Razer (primary) / Stripe (backup)
- **Media Players**: YouTube Player Flutter & Syncfusion PDF Viewer
- **State Management**: Provider
- **Navigation**: go_router
- **Local Storage**: Hive

## 🚀 Getting Started

### Prerequisites
- Flutter SDK 3.8.1+
- Dart SDK 3.8.1+
- Android Studio / VS Code
- iOS development tools (for iOS builds)

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd ruwaq_jawi
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the app**
   ```bash
   # Development
   flutter run -t lib/main_development.dart
   
   # Staging
   flutter run -t lib/main_staging.dart
   
   # Production
   flutter run -t lib/main_production.dart
   ```

## 📁 Project Structure

```
lib/
├── core/
│   ├── config/
│   │   ├── app_config.dart          # App configuration
│   │   └── environment.dart         # Environment management
│   ├── constants/
│   │   └── app_constants.dart       # App constants
│   ├── theme/
│   │   └── app_theme.dart          # App theming
│   └── utils/
│       └── app_router.dart         # Navigation routing
├── main.dart                       # Main entry point
├── main_development.dart           # Development entry
├── main_staging.dart              # Staging entry
└── main_production.dart           # Production entry
```

## 🛠 Build Configurations

The app supports three build environments:

- **Development**: `flutter run -t lib/main_development.dart`
- **Staging**: `flutter run -t lib/main_staging.dart`
- **Production**: `flutter run -t lib/main_production.dart`

## 📋 Development Status

### ✅ Completed (Milestone 1)
- [x] Flutter project setup with proper folder structure
- [x] All required dependencies installed and configured
- [x] Android configuration (minSdk 21, targetSdk 34, compileSdk 34)
- [x] iOS configuration ready
- [x] Git setup with comprehensive .gitignore
- [x] Multi-environment build configurations
- [x] App theming with Islamic-inspired design
- [x] Navigation routing structure
- [x] Core project architecture

### 🔄 Next Steps (Milestone 2)
- [ ] Database schema creation in Supabase
- [ ] Row Level Security (RLS) policies setup
- [ ] Sample data insertion
- [ ] Database performance optimization

## 🎨 Design System

The app uses an Islamic-inspired color palette:
- **Primary**: Dark Green (#1B4332)
- **Secondary**: Gold (#D4AF37)
- **Background**: Light Gray (#F8F9FA)
- **Surface**: White (#FFFFFF)

## 🔧 Configuration

### Environment Variables
Create environment-specific configuration files:
- `.env.development`
- `.env.staging`
- `.env.production`

### Required Configurations (To be added)
- Supabase project URLs and keys
- Payment gateway configurations
- Firebase configuration files
- App signing certificates

## 📚 Documentation

- [PLANNING.md](PLANNING.md) - Comprehensive project planning
- [CLAUDE.md](CLAUDE.md) - Development guidelines
- [TASK.md](TASK.md) - Detailed task breakdown

## 🤝 Contributing

1. Follow the development guidelines in CLAUDE.md
2. Reference PLANNING.md for architectural decisions
3. Use the task breakdown in TASK.md for feature development
4. Maintain the Islamic context and respectful design principles

## 📄 License

This project is proprietary and confidential.

---

**Current Status**: Milestone 1 Complete ✅  
**Next Milestone**: Database Design & Setup  
**Last Updated**: August 28, 2025
