# PSO2 Character Data Manager

> ⚠️ **This is a prototype version.** The app is functional but still in early development. Features may change, and bugs may be present. Feedback and contributions are welcome!

A Windows desktop app built with Flutter for managing Phantasy Star Online 2 character data files locally.

PSO2's salon mode can only display 50 character files at a time. This app acts as an unlimited local library to store, organize, and search your character data outside the game.

---

## Features

- **Unlimited storage** — store as many character files as you want
- **Auto-detection** — race and gender are automatically detected from the file extension
- **Thumbnail support** — attach a screenshot or image to each character
- **Tags** — label characters with custom tags for easy filtering
- **Collections** — organize characters into named folders/groups
- **Search & Filter** — filter by name, race, gender, tags, or collection
- **Dark theme** — PSO2-inspired dark UI

---

## Supported File Types

| Extension | Race | Gender |
|-----------|------|--------|
| `.fhp` | Human | Female |
| `.mhp` | Human | Male |
| `.fnp` | Newman | Female |
| `.mnp` | Newman | Male |
| `.fdp` | Deuman | Female |
| `.mdp` | Deuman | Male |
| `.fcp` | CAST | Female |
| `.mcp` | CAST | Male |

---

## Download

Go to the [Releases](../../releases) page and download the latest ZIP. Unzip it and run `pso2_character_manager.exe`. No installation needed.

---

## Building from Source

**Requirements:**
- Flutter SDK 3.16 or newer
- Windows with Developer Mode enabled
- Visual Studio 2022 with "Desktop development with C++" workload

**Steps:**

```bash
# 1. Clone the repo
git clone https://github.com/LittleSoldier2185/pso2-character-manager.git
cd pso2-character-manager

# 2. Get packages
flutter pub get

# 3. Generate Hive adapters
dart run build_runner build --delete-conflicting-outputs

# 4. Run in debug mode
flutter run -d windows

# 5. Or build a release EXE
flutter build windows --release
```

---

## Tech Stack

- [Flutter](https://flutter.dev) — UI framework
- [Hive](https://pub.dev/packages/hive) — Local database
- [Provider](https://pub.dev/packages/provider) — State management
- [file_picker](https://pub.dev/packages/file_picker) — File selection dialogs

---

## License

MIT License — free to use, modify, and share.
