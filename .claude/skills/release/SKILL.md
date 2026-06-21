# Release Skill

Trigger: user says "do release cycle", "release as vX.Y.Z", "release this", or asks to bump version and push.

## What this skill does

Runs the full release cycle for PSO2 Character Manager:
1. Determine the new version (from user or by incrementing the patch number in `pubspec.yaml`)
2. Add a patch note entry to `lib/patch_notes.dart`
3. Create `RELEASE_vX.Y.Z.txt` in the project root
4. Bump `version:` in `pubspec.yaml`
5. Commit and push to GitHub

## Steps

### 1 — Determine version
Read current version from `pubspec.yaml` line `version:`. If user didn't specify a new version, increment the patch number (1.4.2 → 1.4.3).

### 2 — Patch note entry (`lib/patch_notes.dart`)
Insert a new `_PatchEntry` at the TOP of the `_entries` list (before the previous latest entry). Format:

```dart
_PatchEntry('X.Y.Z', '<short title>', '''
<SECTION HEADER>

• <bullet> — <description>
'''),
```

Section headers are ALL CAPS (e.g. `BUG FIX`, `IMPROVEMENT`, `NEW FEATURE`).
Bullets bold up to the em-dash automatically — keep the `—` separator.

### 3 — RELEASE_vX.Y.Z.txt
Create in project root. Format mirrors the existing RELEASE files:

```
PSO2 Character Manager vX.Y.Z
<short title>

<SECTION HEADER>

• <same bullets as patch note>
```

### 4 — Bump pubspec.yaml
Change the `version:` line. This is the single source of truth — `kAppVersion` reads from the exe at runtime via `package_info_plus`.

### 5 — Commit and push
Stage only the relevant files (never `.claude/`, never `pubspec.lock`):
- `lib/patch_notes.dart`
- `lib/services/app_updater.dart` (if changed)
- `lib/services/app_update_service.dart` (if changed)
- `lib/screens/settings_screen.dart` (if changed)
- `lib/main.dart` (if changed)
- `pubspec.yaml`
- `RELEASE_vX.Y.Z.txt`
- Any other changed lib files

Commit message format:
```
vX.Y.Z - <short title>

<one or two lines describing what changed and why>

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
```

Then `git push`.

## Key facts about this project

- Version lives only in `pubspec.yaml` — do NOT edit `kAppVersion` in `app_update_service.dart` (it's set at runtime)
- GitHub repo: `LittleSoldier2185/pso2-character-manager`
- `pubspec.lock` is gitignored — never stage it
- Previous release files follow `RELEASE_vX.Y.Z.txt` naming
