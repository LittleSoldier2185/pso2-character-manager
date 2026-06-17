# PSO2 Character Manager

A Windows desktop app built with Flutter for managing Phantasy Star Online 2 character data files locally.

Store, organize, and manage an unlimited number of PSO2 character data files outside the game.

---

## PSO2 Character Data Manager v1.0.0

**First stable release!** 🎉

---

### ✨ Features

**Library**
- Grid view of all your characters with thumbnail, name, race, gender, description, and tags
- Keyword token search — type a keyword and press Enter to add it as a search token, click Apply to filter. Supports searching by name, tags, description, and race simultaneously
- Sort by Name A→Z / Z→A, Newest first, Oldest first, or Last applied
- Filter panel for race, gender, applied status, and collection

**Characters**
- Auto-detects race and gender from the character file extension (.fhp, .mhp, .fnp, .mnp, .fdp, .mdp, .fcp, .mcp)
- Drag and drop character files and thumbnail images directly from Windows Explorer
- Add description/notes to each character
- Assign characters to multiple collections at once
- Custom tags for easy filtering
- Full-size thumbnail viewer with zoom support
- Export/share character file to any folder

**Apply to game**
- Apply unlimited characters to your PSO2 game folder with one click
- Applied screen shows all currently active characters
- Toggle apply/unapply directly from the character card or detail page

**Collections**
- Organize characters into named collections (one character can belong to multiple collections)
- Collection grid with 2×2 character preview or custom thumbnail
- Search collections by name
- Search characters inside a collection
- Create, rename, and delete collections

**Settings**
- Custom save location for all character files and thumbnails — with optional file migration when changing folders
- PSO2 game folder path configuration
- Scan game folder for unregistered character files and import them directly
- Accent color theme — choose from 6 PSO2-inspired colors (Cyan, Azure, Purple, Gold, Green, Coral)

---

### 📥 How to install

1. Download the ZIP from the [Releases](../../releases) page
2. Extract it anywhere on your PC
3. Run `pso2_character_manager.exe`
4. No installation required

> **Windows may show a security warning** the first time. Click **More info → Run anyway** to proceed. This is normal for unsigned apps.

---

### 💾 System requirements

- Windows 10 or later (64-bit)
- No internet connection required
- All data stored locally on your PC

---

### 📁 Supported file types

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
- [desktop_drop](https://pub.dev/packages/desktop_drop) — Drag and drop support

---

## License

MIT License — free to use, modify, and share.
