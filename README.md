# Alkamal Library

A Flutter app for a medical bookstore that serves university students. Students use it to order printed lectures and medical supplies, send their own PDFs for printing, and track orders until they arrive. The app is in production on Google Play, and the whole interface is in Arabic (RTL).

This repository contains the student app and its Cloud Functions. The admin dashboard is a separate, private project.

## What the app does

- Browse around 5,000 lectures organized by faculty, year and semester, with a preview of the first page and the price calculated from page count and paper size.
- Order full subjects as a bundle, with optional binding.
- Upload a PDF, choose color, single or double sided, copies and binding, and see the price before ordering.
- Shop for medical supplies, apply promo codes, and choose delivery on a map or pickup from the store.
- Follow the order status and get push notifications when it is accepted or on its way.
- Ask an in-app assistant about products, prices and order status.

## How it is built

**App:** Flutter and Dart, Material 3, custom light and dark themes, `flutter_map` and `geolocator` for delivery locations, `pdfx` for PDF previews.

**Backend:** Firebase. Firestore for data, Storage for files, Auth with phone verification, Cloud Messaging for notifications, and Crashlytics.

**Cloud Functions (Node.js):**

- `placeOrder` recalculates every price on the server from Firestore, including print jobs and bundles, and applies promo codes inside a transaction. The client never decides what an order costs.
- `validatePromo` checks a single code without exposing the list of codes.
- Notification triggers for new orders and status changes.
- `ragChat` runs the assistant with tool calls to search products, read product details and check the caller's own orders, with basic rate limiting.

## Project structure

```
lib/
  main.dart            entry point and feature flags
  app_theme.dart       colors and themes
  data.dart            data models
  models/              order status, chat messages
  services/            Firestore, auth, chat, uploads, notifications
  screens/             app screens
  widgets/             shared UI components
functions/
  index.js             Cloud Functions
```

## Running it locally

Firebase config files are not included in this repository. To run the app you need your own Firebase project and the generated files:

- `lib/firebase_options.dart` (generate with `flutterfire configure`)
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`

Then:

```bash
flutter pub get
flutter run --flavor student -t lib/main.dart
```

## Author

Muhannad Daboul. You can reach me at muhannad.daboul@hotmail.com
