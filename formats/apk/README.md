# APK

- **Расширение:** `.apk`.
- **Где запускается:** Android-приложение с иконкой.
- **Состояние:** 🟡 пишется (ветка apk):
  - `zip.saltic` — zip без сжатия, выравнивание блоком 0xD935, CRC32;
  - `manifest.saltic` — двоичный манифест (AXML), приложение NativeActivity без Java.
- **Сборка:** `just android <имя>` в saltic-soft — сборщик `soul/toolchains/android`, программа `soft/<категория>/<имя>/android`, `.so` из `compiler/gorn/linker/shared`, подпись `apksigner`.
- **Заметка:** Java нет: Android сам грузит `lib/arm64-v8a/libmain.so` через NativeActivity.
