<div align="center">

# 🟦 Survexus — Smart Survey Creation & Analytics App

**Create. Analyze. Scale. — A powerful survey ecosystem with built-in AI intelligence**

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Backend-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)](https://firebase.google.com)
[![Groq AI](https://img.shields.io/badge/Groq-LLaMA--3.3--70B-black?style=for-the-badge)]()
[![Version](https://img.shields.io/badge/Version-1.0.0-orange?style=for-the-badge)]()
[![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)]()

> A Feature rich-ready cross-platform survey platform that enables users to **create surveys, collect responses, visualize analytics**, and interact with an **AI-powered assistant** — all in a seamless, role-based system.

</div>

---

## 📱 Features

### 👤 User Roles

| Role   | Capabilities |
|--------|-------------|
| **Guest**  | Respond to surveys only (no creation or analytics access) |
| **User**   | Create surveys, respond, and view analytics for owned surveys |
| **VIP**    | Unlimited surveys, advanced analytics, premium features, no upsell UI |
| **Admin**  | Full system control — manage users, surveys, and VIP access |

---

### 🧩 Core Functionalities

#### 📝 Survey Creation
- Multiple question types (flexible structure)
- Visibility control (public/private)
- Duplicate-response prevention
- Guest-safe participation mode

#### 📥 Survey Responses
- Fast and intuitive response UI
- Guest participation supported
- Real-time response storage using Firebase Firestore
- Anti-duplicate submission logic

#### 📊 Analytics Dashboard
- Bar charts & pie charts for insights
- Survey-specific analytics separation
- Clean, readable data visualization
- Real-time updates

#### ⚙️ Survey Management
- Edit / delete surveys
- Real-time response count tracking
- Organized response handling

#### 🛡️ Admin Panel
- User search and management
- Activate / close / delete surveys
- Grant or revoke VIP access

#### 💎 VIP Features
- Advanced analytics access
- Unlimited survey creation
- Premium experience (no upsell interruptions)

#### 🤖 AI Assistant
- Powered by Groq LLaMA-3.3-70B
- Role-aware responses (guest/user/admin/VIP context)
- Helps with survey creation and insights

---

## 🛠️ Tech Stack

| Layer | Technology |
|------|-----------|
| **Framework** | Flutter 3.x / Dart |
| **State Management** | Provider |
| **Backend** | Firebase Auth · Firestore · Cloud Messaging |
| **AI Integration** | Groq LLaMA-3.3-70B |

---

## 🏗️ Architecture

Clean modular structure for scalability and maintainability:

lib/
├── models/
├── providers/
├── screens/
├── services/
├── utils/
├── widgets/
├── secrets.dart
├── main.dart
assets/
android/
ios/
test/

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK >=3.0.0 <4.0.0
- Firebase project setup
- Groq API key

### Setup

git clone https://github.com/your-username/survexus.git
cd survexus

flutter pub get
flutter run

---

## 🧪 Testing

- VIP upsell visibility logic
- VIP feature restrictions
- Admin panel access control

flutter test

---

## 📦 Build

### Debug
flutter run

### Release APK
flutter build apk --release

Output:
build/app/outputs/flutter-apk/app-release.apk

---

## 🎨 Splash Screen

- Native Android splash (white background, centered logo)
- Config files:
  - launch_background.xml
  - styles.xml
  - MainActivity.kt

---

## 🔐 Security

- API keys, keystores, and configs are never committed
- secrets.dart is ignored via .gitignore
- GitHub Push Protection prevents accidental leaks

---

## 🗺️ Roadmap

- [ ] Survey scheduling
- [ ] Collaborative surveys
- [ ] AI-generated survey questions

---

## 👨‍💻 Author

Rahul Walawalkar  
walawalkarrahul729@gmail.com  
https://github.com/raahu1l

---

<div align="center">

Built with Flutter · Star ⭐ if you find it useful

</div>
