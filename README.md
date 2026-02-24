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
flutter run
```

You may want to create a separate Android Wear OS module or integrate this `lib/` and `pubspec.yaml` into a full Flutter project created via `flutter create`.

## Running in physical device

```bash
$ adb pair 192.168.100.193:38235
Enter pairing code: 951151
Successfully paired to 192.168.100.193:38235 [guid=adb-RXAYA00FMLR-bRYXeY]
```


```bash
$ adb connect 192.168.100.193:44883
connected to 192.168.100.193:44883
```

