# 🟦 Survexus — Smart Survey Creation & Analytics App

A cross-platform Flutter application for creating surveys, collecting responses, viewing analytics dashboards, and chatting with an in-app AI assistant.

Supports guest mode, standard users, VIP users, and an admin panel.

---

## 🚀 Features Overview

### 👤 User Roles

| Role   | Features                                                                                                       |
|--------|----------------------------------------------------------------------------------------------------------------|
| Guest  | Respond to surveys only. Cannot create surveys or view analytics.                                              |
| User   | Create surveys, respond to surveys, see analytics for their own surveys.                                       |
| VIP    | Unlimited surveys, advanced analytics, VIP-only features, no upsell banners.                                   |
| Admin  | Access to admin panel, manage system-level settings, activate/close surveys, give VIP access.                  |

---

### 📱 Core App Features

- **Create Surveys:** Multiple question types, visibility management, duplicate-response protection, guest-safe mode
- **Respond to Surveys:** Fast UI, guest mode, duplicate response prevention, tracks and stores responses in Firebase Firestore
- **Survey Management:** Edit/delete surveys, view number of responses (real-time), organized response management
- **Analytics Dashboard:** Bar charts, pie charts, analytics separated by survey ID, readable layouts
- **Admin Controls:** Track/search users, activate/delete/close surveys, manage VIP access

- **VIP users:** Enhanced analytics, exclusive features
- **In-App AI Chatbot:** Groq Llama-3.3-70B, fully role-based answers

---

### 🔐 Security

- **API keys, keystore files, Google Services configs, APKs:** Never committed; protected by `.gitignore`
- **lib/secrets.dart** is ignored in git and stores keys only at runtime
- **GitHub Push Protection:** Repo blocks any push containing keys or secrets

---

### 🗄️ Tech Stack

**Frontend:**  
Flutter 3.x, Dart, Provider (state management)

**Backend:**  
Firebase Auth, Firebase Firestore, Firebase Cloud Messaging

**AI Integration:**  
Groq Llama-3.3-70B, role-aware agent

---

### 📁 Project Structure

lib/
├── models/
├── providers/
├── screens/
├── services/
├── utils/
├── widgets/
├── secrets.dart # IGNORED — contains Groq API key
├── main.dart # bootstrap + splash init
assets/
android/
ios/
test/ # Flutter tests

text

---

### 🧪 Testing

- VIP upsell visibility (guest → upsell visible; VIP → hidden)
- VIP feature restriction
- Admin panel hidden from non-admins

**Run tests:**  
`flutter test`

---

### 🏁 Running the App

**Debug:**  
`flutter run`

**Release APK:**  
`flutter build apk --release`

APK output:  
`build/app/outputs/flutter-apk/app-release.apk` (attach to GitHub releases)

---

### 🎨 App Splash Screen

- Native Android splash (white background, centered Survexus logo)
- Configured in:  
  - `android/app/src/main/res/drawable/launch_background.xml`  
  - `styles.xml`  
  - `MainActivity.kt`

---

### 🛠️ Build & Deployment Notes

**Never commit:**  
- API keys  
- Keystore files (`.jks`, `.keystore`)  
- `google-services.json`  
- APK builds

These are protected by `.gitignore`.

**GitHub Push Protection:**
- If you accidentally commit a key, the push will be blocked.
- Remove the secret, amend the commit, and push again.

---

### 📦 Future Enhancements

- Survey scheduling
- Collaborative survey creation
- AI-generated survey questions

---

### Example Admin Accounts

- Professor Admin  

- Student Admin  
  Email: rahul@gmail.com
