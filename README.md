# SafeMed

A mobile application to foster safer medication adoption.

SafeMed is a multiplatform Flutter application designed to support users in the safe management of their medications. The app helps with medication adherence, risk analysis, and prescription management.

## 📚 Documentation

### Start Here
- **[QUICK_START.md](QUICK_START.md)** - Test the prescription parser fix (start here!)
- **[USER_MANUAL.md](USER_MANUAL.md)** - Complete user guide for all features

### For Testing
- **[TEST_PRESCRIPTIONS.md](TEST_PRESCRIPTIONS.md)** - Working prescription examples and formats

### Technical Details
- **[PRESCRIPTION_FIX.md](PRESCRIPTION_FIX.md)** - Details about the manual entry fix
- **[TOPIC2_ASSESSMENT.md](TOPIC2_ASSESSMENT.md)** - Profile management implementation analysis
- **[IMPROVEMENTS.md](IMPROVEMENTS.md)** - Suggested enhancements (19 items)

## 🚀 Quick Start

### Prerequisites
- Flutter SDK (latest stable)
- Dart SDK
- Android Studio / Xcode (for mobile development)

### Installation
```bash
cd safemed
flutter pub get
flutter run
```

### Testing the Prescription Parser
1. Launch the app
2. Create a test profile
3. Go to "New prescription plan"
4. Enter this test prescription:
```
Metformina 500 mg 2x dia
Paracetamol 1000 mg 8/8h
Omeprazol 20 mg 1 comprimido ao pequeno almoco
```
5. Click "Analyze & create plan"
6. Review extracted details and confirm
7. Check that doses and times are pre-populated

See **[QUICK_START.md](QUICK_START.md)** for detailed testing instructions.

## ✨ Features

### Current Features
- ✅ **Profile Management** - Multiple patient profiles with health conditions
- ✅ **Prescription Parsing** - OCR and manual text entry with intelligent parsing
- ✅ **Medication Database** - Portuguese (PT-BR/PT-PT) medication database
- ✅ **Plan Management** - Schedule medications with doses and times
- ✅ **Administration View** - Today's medication schedule
- ✅ **Alerts** - Pending medication notifications
- ✅ **Risk Analysis** - Basic contraindication checking
- ✅ **Medication Explorer** - Search by symptoms, scan barcodes/labels

### Recent Updates (March 6, 2026)
- 🔧 **Fixed:** Manual prescription entry now parses text (not just names)
- 🔧 **Added:** Automatic time generation based on frequency
- 🔧 **Added:** Pre-population of plan form with extracted details
- 📖 **Updated:** User manual with correct workflows
- 📝 **Created:** Comprehensive test prescription examples

## 🏗️ Project Structure

```
lib/
├── main.dart                   # App entry point
├── models/                     # Data models
│   ├── profile.dart
│   ├── prescription_plan.dart
│   ├── medication_entry.dart
│   └── medication_match.dart
├── services/                   # Business logic & storage
│   ├── profile_store.dart
│   ├── plan_store.dart
│   ├── alert_store.dart
│   ├── prescription_parser.dart
│   ├── risk_engine.dart
│   └── ocr_service.dart
├── screens/                    # UI screens
│   ├── home_screen.dart
│   ├── profile_*.dart          # Profile management
│   ├── prescription_screen.dart # Prescription entry (RECENTLY FIXED)
│   ├── plan_*.dart             # Plan management
│   └── scanner/                # OCR & barcode scanning
├── data/                       # Medication databases
│   ├── medications_pt_br.dart
│   └── medications_pt_pt.dart
└── utils/
    └── plan_schedule.dart
```

## 📋 Topic 2: Profile Management Assessment

### Implementation Status: ✅ 85% Complete

**Implemented:**
- Multiple profiles per device/account ✓
- Profile switching ✓
- Health condition tracking (renal, hepatic, diabetes, hypertension) ✓
- Profile-plan association ✓
- Profile-alert association ✓
- CRUD operations (create, read, update, delete) ✓

**Missing from Requirements:**
- Allergies field (structured tracking)
- Medical restrictions field  
- Profile categories (adult/child/elderly)
- Medication history tracking

See **[TOPIC2_ASSESSMENT.md](TOPIC2_ASSESSMENT.md)** for complete analysis.

## 🔧 Development

### Run in Debug Mode
```bash
flutter run
```

### Build for Release
```bash
# Android
flutter build apk --release

# iOS
flutter build ios --release
```

### Run Tests
```bash
flutter test
```

## 📱 Supported Platforms
- Android
- iOS
- (Flutter supports Web/Desktop but not tested)

## 🌍 Language Support
- **UI:** English
- **Medication Database:** Portuguese (PT-BR, PT-PT)
- **Parser:** Portuguese medical terminology

## ⚠️ Important Notes

### Medical Disclaimer
SafeMed is a medication management support tool. It is **NOT** a substitute for professional medical advice, diagnosis, or treatment. Always consult healthcare professionals.

### Data Privacy
- All data stored locally (SharedPreferences)
- No cloud sync in current version
- No user accounts required
- Uninstalling deletes all data

### Current Limitations
- No cloud backup
- No dose confirmation tracking
- Basic risk analysis only
- Limited medication database (Portuguese only)
- No comprehensive drug interaction checking

## 🛠️ Recent Fix: Manual Prescription Entry

### What Was Fixed
Manual text entry now uses the prescription parser to:
- Extract medication names, strengths, doses, frequencies
- Auto-generate administration times
- Pre-populate the plan form

### Before
```
Enter: "Metformina 500 mg 2x dia"
Result: Only "Metformina" as name, manual dose/time entry required
```

### After
```
Enter: "Metformina 500 mg 2x dia"
Result: Name, dose (500 mg), times (08:00, 20:00) all auto-populated ✨
```

See **[PRESCRIPTION_FIX.md](PRESCRIPTION_FIX.md)** for details.

## 📖 Documentation Files

| File | Purpose |
|------|---------|
| [QUICK_START.md](QUICK_START.md) | Step-by-step testing guide |
| [USER_MANUAL.md](USER_MANUAL.md) | Complete user manual |
| [TEST_PRESCRIPTIONS.md](TEST_PRESCRIPTIONS.md) | Example prescriptions that work |
| [PRESCRIPTION_FIX.md](PRESCRIPTION_FIX.md) | Technical details of the fix |
| [TOPIC2_ASSESSMENT.md](TOPIC2_ASSESSMENT.md) | Profile management analysis |
| [IMPROVEMENTS.md](IMPROVEMENTS.md) | Enhancement suggestions |

## 🤝 Contributing

This is an academic/research project. For questions or contributions, contact the development team.

## 📄 License

[Add your license information here]

## 📞 Support

For issues or questions:
1. Check the **[USER_MANUAL.md](USER_MANUAL.md)** troubleshooting section
2. Review **[TEST_PRESCRIPTIONS.md](TEST_PRESCRIPTIONS.md)** for format examples
3. Contact the development team

---

**Last Updated:** March 6, 2026  
**Version:** Development Build  
**Status:** ✅ Prescription parser fixed and tested
