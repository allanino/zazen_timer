## Zazen Timer (Wear OS / Flutter)

This is a simple zazen timer intended for Wear OS, implemented in Flutter.

### Features

- **Configurable session presets** with multiple steps:
  - Pre-start (time before zazen actually begins)
  - Zazen blocks
  - Optional kinhin blocks between zazen periods
- **Haptic-only guidance**:
  - Three medium vibrations when zazen starts
  - Two medium vibrations when transitioning from zazen to kinhin
  - Three medium vibrations when transitioning from kinhin back to zazen
  - One long vibration at the end of the session
- **Circular countdown display** similar to Samsung timers, with:
  - Large, centered remaining time
  - Progress ring around the watch face

### Running

1. Ensure you have Flutter installed and configured for Wear OS / Android.
2. From this directory, run:

```bash
flutter pub get
dart run flutter_launcher_icons   # (re)generate app icons
flutter run
```

You may want to create a separate Android Wear OS module or integrate this `lib/` and `pubspec.yaml` into a full Flutter project created via `flutter create`.

### Build and install release APK on the watch

1. **Build the release APK**

   From the project directory:

   ```bash
   flutter build apk --release
   ```

   The APK is produced at: `build/app/outputs/flutter-apk/app-release.apk`

   > Release builds use `isMinifyEnabled = false` in `android/app/build.gradle.kts` to avoid an R8/ProGuard parse error from a dependency. The APK is larger but works reliably.

2. **Enable developer options on the watch**

   - **Settings → About** → tap **Build number** 7 times.
   - **Settings → Developer options** → enable **ADB debugging** and **Debug over Wi‑Fi** (or **Wireless debugging** on Wear OS 3/4).
   - Note the watch IP and, for Wireless debugging, the pairing and connection ports.

3. **Connect from your machine**

   Ensure the watch and your computer are on the same Wi‑Fi network. Install `adb` if needed (e.g. `sudo apt install android-tools-adb` on Debian/Ubuntu).

   On **Wear OS 3+** with Wireless debugging you may need to pair first, then connect:

   ```bash
   adb pair <WATCH_IP>:<PAIRING_PORT>
   # Enter the pairing code shown on the watch when prompted.

   adb connect <WATCH_IP>:<CONNECT_PORT>
   adb devices   # confirm the watch is listed
   ```

   On older Wear OS with **Debug over Wi‑Fi**, use:

   ```bash
   adb connect <WATCH_IP>:5555
   adb devices
   ```

4. **Install the release APK**

   From the project directory:

   ```bash
   adb install -r build/app/outputs/flutter-apk/app-release.apk
   ```

   The `-r` flag allows replacing an existing install (e.g. a debug build). Open the app from the watch app list.

