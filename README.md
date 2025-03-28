# Chalokart User App

Chalokart is a Flutter-based mobile application that provides a seamless user experience for location-based services. The app integrates with Firebase for authentication and real-time data management, and uses Google Maps for location services.

## Features

- User Authentication with Firebase
- Real-time Location Tracking
- Google Maps Integration
- Dark/Light Theme Support
- Push Notifications
- Payment Integration (Razorpay)
- Rating System
- Location-based Services

## Prerequisites

Before you begin, ensure you have the following installed:
- Flutter SDK (version 3.7.0 or higher)
- Android Studio / VS Code
- Git
- Firebase CLI (optional, for Firebase setup)

## Installing Flutter SDK

### For macOS:

1. Download the Flutter SDK from [Flutter's official website](https://flutter.dev/docs/get-started/install/macos)
2. Extract the downloaded file to a desired location (e.g., `~/development/flutter`)
3. Add Flutter to your PATH by adding the following line to your `~/.zshrc` or `~/.bash_profile`:
   ```bash
   export PATH="$PATH:[PATH_TO_FLUTTER]/flutter/bin"
   ```
4. Run `source ~/.zshrc` or `source ~/.bash_profile` to reload the terminal
5. Verify the installation by running:
   ```bash
   flutter doctor
   ```

### For Windows:

1. Download the Flutter SDK from [Flutter's official website](https://flutter.dev/docs/get-started/install/windows)
2. Extract the zip file to a desired location (e.g., `C:\src\flutter`)
3. Add Flutter to your PATH by adding `C:\src\flutter\bin` to your system's PATH environment variable
4. Open a new terminal and verify the installation:
   ```bash
   flutter doctor
   ```

### For Linux:

1. Download the Flutter SDK from [Flutter's official website](https://flutter.dev/docs/get-started/install/linux)
2. Extract the file to a desired location (e.g., `~/development/flutter`)
3. Add Flutter to your PATH by adding the following line to your `~/.bashrc`:
   ```bash
   export PATH="$PATH:[PATH_TO_FLUTTER]/flutter/bin"
   ```
4. Run `source ~/.bashrc` to reload the terminal
5. Verify the installation:
   ```bash
   flutter doctor
   ```

## Setting up the Project

1. Clone the repository:
   ```bash
   git clone [YOUR_REPOSITORY_URL]
   cd chalokart_user
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Set up Firebase:
   - Create a new Firebase project in the [Firebase Console](https://console.firebase.google.com/)
   - Add your Android/iOS app to the Firebase project
   - Download and add the `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) files to their respective locations
   - For Android: Place `google-services.json` in `android/app/`
   - For iOS: Place `GoogleService-Info.plist` in `ios/Runner/`

4. Configure Google Maps:
   - Get a Google Maps API key from the [Google Cloud Console](https://console.cloud.google.com/)
   - For Android: Add the API key to `android/app/src/main/AndroidManifest.xml`
   - For iOS: Add the API key to `ios/Runner/AppDelegate.swift`

## Running the App

1. Open an emulator or connect a physical device

2. Run the app:
   ```bash
   flutter run
   ```

3. Select your target device when prompted

## Project Structure

```
chalokart_user/
├── lib/
│   ├── main.dart              # App entry point
│   ├── screens/               # UI screens
│   ├── models/                # Data models
│   ├── services/              # Business logic
│   └── utils/                 # Utility functions
├── assets/                    # Static assets
├── android/                   # Android-specific files
├── ios/                       # iOS-specific files
└── pubspec.yaml              # Project dependencies
```

## Dependencies

The app uses several key packages:
- `firebase_core`: Firebase core functionality
- `firebase_auth`: User authentication
- `google_maps_flutter`: Maps integration
- `provider`: State management
- `geolocator`: Location services
- `razorpay_flutter`: Payment processing

## Troubleshooting

If you encounter any issues:

1. Run `flutter doctor` to check for any system configuration issues
2. Ensure all dependencies are up to date with `flutter pub get`
3. Clean the project with `flutter clean` and rebuild
4. Check the Firebase configuration files are properly set up
5. Verify your Google Maps API key is correctly configured

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details. 
