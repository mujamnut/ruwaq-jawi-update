# PLANNING.md - Maktabah App Development Planning

## 🌟 Vision & Mission

### Vision Statement
**"To become the premier digital platform for Islamic education, making authentic Islamic knowledge accessible to students and learners worldwide through modern technology."**

### Mission Statement
**"We provide a comprehensive mobile learning experience that combines traditional Islamic scholarship with modern digital convenience, offering structured access to authentic Islamic books and educational videos through an affordable subscription model."**

### Core Values
- **Authenticity**: Curated content from trusted Islamic scholars and sources
- **Accessibility**: Easy-to-use interface for learners of all technical levels
- **Affordability**: Subscription model that makes knowledge accessible to students
- **Quality**: High-quality digital content with excellent user experience
- **Innovation**: Leveraging modern technology to enhance Islamic education

---

## 🎯 Product Strategy

### Target Market
**Primary Audience:**
- University students studying Islamic subjects
- Islamic studies enthusiasts
- Madrasah students and teachers
- General Muslim community seeking Islamic knowledge

**Geographic Focus:**
- Primary: Malaysia, Indonesia, Brunei
- Secondary: Middle East, South Asia
- Tertiary: Global Muslim community

### Value Proposition
- **Unified Learning Experience**: Video lectures synchronized with corresponding textbooks
- **Flexible Access**: Learn anywhere, anytime with mobile-first design
- **Structured Content**: Organized by categories and difficulty levels
- **Affordable Knowledge**: Multiple subscription tiers for different budgets
- **Progress Tracking**: Bookmark and track learning progress

### Success Metrics
- **User Acquisition**: 10,000+ downloads in first 6 months
- **Subscription Rate**: 15% conversion from free to paid users
- **User Engagement**: Average 30+ minutes daily usage
- **Content Completion**: 60% of users complete at least one full kitab
- **Revenue Target**: $50,000 ARR by end of year 1

---

## 🏗 System Architecture

### High-Level Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│                 │    │                 │    │                 │
│   Flutter App   │◄──►│   Supabase      │◄──►│   External      │
│   (iOS/Android) │    │   Backend       │    │   Services      │
│                 │    │                 │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
        │                       │                       │
        │                       │                       │
        ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│                 │    │                 │    │                 │
│  • Student UI   │    │  • Database     │    │  • Stripe       │
│  • Admin UI     │    │  • Auth         │    │  • ToyyibPay    │
│  • Media Player │    │  • Storage      │    │  • CDN          │
│  • Offline Cache│    │  • Edge Funcs   │    │  • Analytics    │
│                 │    │                 │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### Architecture Principles
1. **Mobile-First**: Optimized for mobile devices with responsive design
2. **Scalable**: Built to handle growing user base and content library
3. **Secure**: Content protection and secure payment processing
4. **Performant**: Fast loading times and smooth media playback
5. **Maintainable**: Clean code architecture with proper separation of concerns

### Data Flow Architecture

```
User Action → Flutter UI → State Management → Supabase API → Database
                    ↓
              Local Storage ← Content Cache ← Media CDN ← Supabase Storage
```

### Security Architecture
- **Authentication**: Supabase Auth with JWT tokens
- **Authorization**: Row Level Security (RLS) policies
- **Content Protection**: Signed URLs for premium content
- **Payment Security**: PCI-compliant payment gateways
- **Data Encryption**: End-to-end encryption for sensitive data

---

## 💻 Technology Stack

### Frontend Development
**Framework**: Flutter 3.x
- **Language**: Dart 3.x
- **UI Framework**: Material Design 3 / Cupertino
- **State Management**: Provider / Riverpod / Bloc (TBD)
- **Navigation**: go_router
- **Local Storage**: Hive / SharedPreferences

### Backend Services
**Primary Backend**: Supabase
- **Database**: PostgreSQL (managed by Supabase)
- **Authentication**: Supabase Auth
- **Storage**: Supabase Storage
- **Real-time**: Supabase Realtime
- **Edge Functions**: Deno-based serverless functions

### Media & Content Delivery
**Video Streaming**:
- YouTube embedded videos via YouTube Data API
- YouTube video links stored in database
- Flutter youtube_player_flutter for playback
- No local video storage required

**PDF Handling**:
- Supabase Storage for PDF files
- Local caching for offline access
- Progressive loading for large files

### Payment Processing
**Primary Gateway**: Chip by Razer (Malaysia)
- Credit/Debit cards
- Online banking (FPX)
- Digital wallets (Boost, GrabPay, TouchNGo)
- Subscription management

**Backup Gateway**: Stripe (International)
- Credit/Debit cards
- International payment methods
- For non-Malaysian users

### Third-Party Services
**Analytics**: Firebase Analytics
**Crash Reporting**: Firebase Crashlytics
**Push Notifications**: Firebase Cloud Messaging
**App Distribution**: Google Play Store, Apple App Store

---

## 🛠 Development Tools & Environment

### Development Environment
**IDE/Editor**:
- Visual Studio Code (Primary)
- Android Studio (Android-specific debugging)
- Xcode (iOS-specific debugging)

**Version Control**:
- Git (Version control)
- GitHub/GitLab (Repository hosting)
- Git Flow (Branching strategy)

### Flutter Development Tools
**Essential Tools**:
```bash
Flutter SDK 3.x
Dart SDK 3.x
Flutter DevTools
Pub.dev package manager
```

**Development Commands**:
```bash
flutter doctor          # Check development setup
flutter create          # Create new project
flutter pub get         # Install dependencies
flutter run             # Run app
flutter build           # Build for production
flutter test            # Run tests
```

### Design & Prototyping
**UI/UX Design**:
- Figma (UI Design & Prototyping)
- Adobe XD (Alternative design tool)
- Material Design Guidelines
- Human Interface Guidelines

**Assets & Icons**:
- Flutter app icons plugin
- Custom icon fonts
- SVG assets
- Optimized images (WebP format)

### Testing Tools
**Testing Framework**:
- Flutter Test (Unit testing)
- Integration Test (Widget testing)
- Golden Test (Visual regression testing)

**Device Testing**:
- Android Emulator
- iOS Simulator
- Physical devices (various screen sizes)
- BrowserStack (Cloud testing)

### Build & Deployment
**CI/CD Pipeline**:
- GitHub Actions / GitLab CI
- Fastlane (iOS deployment)
- Gradle (Android deployment)

**Code Quality**:
- Dart analyzer
- Flutter lints
- SonarQube (Code quality analysis)
- Codecov (Code coverage)

---

## 📦 Required Dependencies

### Core Flutter Dependencies
```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # Backend & Database
  supabase_flutter: ^2.0.0
  
  # UI & Navigation
  go_router: ^12.0.0
  provider: ^6.1.0  # or riverpod/bloc
  
  # Media Players
  youtube_player_flutter: ^8.1.2
  syncfusion_flutter_pdfviewer: ^23.0.0
  
  # Payment Gateways
  # chip_payment_flutter: ^1.0.0  (Chip SDK if available)
  webview_flutter: ^4.4.0  # For Chip payment web integration
  
  # Storage & Caching
  hive: ^2.2.3
  hive_flutter: ^1.1.0
  shared_preferences: ^2.2.0
  
  # Utilities
  connectivity_plus: ^5.0.0
  path_provider: ^2.1.0
  permission_handler: ^11.0.0
  url_launcher: ^6.2.0
  
  # UI Enhancements
  cached_network_image: ^3.3.0
  shimmer: ^3.0.0
  lottie: ^2.7.0
```

### Development Dependencies
```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  
  # Code Generation
  hive_generator: ^2.0.1
  build_runner: ^2.4.7
  
  # Testing
  mockito: ^5.4.2
  integration_test:
    sdk: flutter
  
  # Code Quality
  flutter_lints: ^3.0.0
  very_good_analysis: ^5.1.0
```

### Native Platform Dependencies
**iOS (ios/Podfile)**:
```ruby
platform :ios, '12.0'
pod 'Firebase/Analytics'
pod 'Firebase/Crashlytics'
```

**Android (android/app/build.gradle)**:
```gradle
minSdkVersion 21
targetSdkVersion 34
compileSdkVersion 34
```

---

## 🗄 Database Schema Design

### Core Tables Structure
```sql
-- User Profiles (extends Supabase auth.users)
profiles (
  id UUID PRIMARY KEY REFERENCES auth.users,
  full_name TEXT,
  role TEXT DEFAULT 'student',
  subscription_status TEXT DEFAULT 'inactive',
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Content Categories
categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  icon_url TEXT,
  sort_order INTEGER,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Kitab (Books/Content)
kitab (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  author TEXT,
  description TEXT,
  category_id UUID REFERENCES categories(id),
  pdf_url TEXT,
  youtube_video_id TEXT, -- YouTube video ID (e.g., 'dQw4w9WgXcQ')
  youtube_video_url TEXT, -- Full YouTube URL for backup
  thumbnail_url TEXT, -- YouTube thumbnail or custom thumbnail
  is_premium BOOLEAN DEFAULT true,
  duration_minutes INTEGER, -- Video duration in minutes
  sort_order INTEGER,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- User Subscriptions
subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id),
  plan_type TEXT NOT NULL, -- '1month', '3month', '6month', '12month'
  start_date TIMESTAMP NOT NULL,
  end_date TIMESTAMP NOT NULL,
  status TEXT DEFAULT 'active', -- 'active', 'expired', 'cancelled'
  payment_method TEXT,
  amount DECIMAL(10,2),
  created_at TIMESTAMP DEFAULT NOW()
);

-- Payment Transactions
transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id),
  subscription_id UUID REFERENCES subscriptions(id),
  amount DECIMAL(10,2) NOT NULL,
  currency TEXT DEFAULT 'MYR',
  payment_method TEXT,
  gateway_transaction_id TEXT,
  status TEXT DEFAULT 'pending', -- 'pending', 'completed', 'failed', 'refunded'
  metadata JSONB,
  created_at TIMESTAMP DEFAULT NOW()
);

-- User Saved Items
saved_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id),
  kitab_id UUID REFERENCES kitab(id),
  folder_name TEXT DEFAULT 'Default',
  created_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(user_id, kitab_id)
);

-- User Reading Progress
reading_progress (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id),
  kitab_id UUID REFERENCES kitab(id),
  video_progress INTEGER DEFAULT 0, -- seconds watched
  pdf_page INTEGER DEFAULT 1,
  last_accessed TIMESTAMP DEFAULT NOW(),
  UNIQUE(user_id, kitab_id)
);
```

---

## 📱 App Configuration

### Build Configurations
**Development Environment**:
```yaml
app_name: "Maktabah Dev"
bundle_id: "com.maktabah.dev"
supabase_url: "https://dev-project.supabase.co"
stripe_publishable_key: "pk_test_..."
```

**Production Environment**:
```yaml
app_name: "Maktabah"
bundle_id: "com.maktabah.app"
supabase_url: "https://prod-project.supabase.co"
stripe_publishable_key: "pk_live_..."
```

### Feature Flags
```yaml
features:
  enable_offline_download: true
  enable_video_quality_selection: true
  enable_dark_mode: true
  enable_push_notifications: true
  enable_analytics: true
  enable_crash_reporting: true
```

---

## 🚀 Deployment Strategy

### Development Workflow
1. **Feature Development**: Feature branches from develop
2. **Code Review**: Pull request with mandatory review
3. **Testing**: Automated tests + manual QA
4. **Staging Deployment**: Deploy to internal testing
5. **Production Release**: Deploy to app stores

### Release Strategy
**Beta Testing**:
- Internal testing (TestFlight/Play Console Internal)
- Closed beta with selected users
- Open beta for wider testing

**Production Release**:
- Phased rollout (10% → 50% → 100%)
- Monitor crash rates and user feedback
- Hotfix process for critical issues

### Monitoring & Analytics
**Key Metrics to Track**:
- App crashes and errors
- User acquisition and retention
- Subscription conversion rates
- Content engagement metrics
- Payment success rates
- App performance metrics

---

## 💰 Budget Estimation

### Development Costs
**Human Resources** (3-4 months):
- Flutter Developer: $15,000 - $25,000
- UI/UX Designer: $3,000 - $5,000
- QA Tester: $2,000 - $3,000

### Infrastructure Costs (Monthly)
**Supabase**: $25 - $100/month (based on usage)
**Payment Processing (Chip)**: 2.8% + RM0.50 per transaction
**YouTube Data API**: Free (up to 10,000 requests/day)
**App Store Fees**: $99/year (Apple) + $25 (Google Play)
**Storage (PDF only)**: $20 - $50/month
**Analytics/Monitoring**: $0 - $50/month

### Estimated Total
**Initial Development**: $20,000 - $35,000
**Monthly Operations**: $100 - $400/month
**First Year Total**: $21,200 - $39,800

---

This planning document serves as the foundation for all development decisions and should be referenced throughout the project lifecycle to ensure alignment with the original vision and technical requirements.