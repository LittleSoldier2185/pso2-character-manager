import 'dart:io';
import 'package:path/path.dart' as p;

enum CharacterTier {
  s, a, b, c, d;

  String get label {
    switch (this) {
      case CharacterTier.s: return 'S';
      case CharacterTier.a: return 'A';
      case CharacterTier.b: return 'B';
      case CharacterTier.c: return 'C';
      case CharacterTier.d: return 'D';
    }
  }

  static const Map<CharacterTier, int> _colours = {
    CharacterTier.s: 0xFFD85A30,
    CharacterTier.a: 0xFFBA7517,
    CharacterTier.b: 0xFF9E9E9E,
    CharacterTier.c: 0xFFB87333,
    CharacterTier.d: 0xFF888780,
  };

  int get colorValue => _colours[this]!;

  static const Map<CharacterTier, int> _bgColours = {
    CharacterTier.s: 0xFFFAECE7,
    CharacterTier.a: 0xFFFAC775,
    CharacterTier.b: 0xFFE8E8E8,
    CharacterTier.c: 0xFFE8C5A0,
    CharacterTier.d: 0xFFD3D1C7,
  };

  int get bgColorValue => _bgColours[this]!;

  static CharacterTier? fromInt(int? value) {
    if (value == null) return null;
    return CharacterTier.values[value.clamp(0, 4)];
  }
}

// ── Variant ────────────────────────────────────────────────────────

class VariantData {
  String folderName;
  String displayName;
  final DateTime createdAt;
  DateTime? lastSyncedAt;
  String? originalFileName;
  bool thumbnailBlurred;

  VariantData({
    required this.folderName,
    required this.displayName,
    DateTime? createdAt,
    this.lastSyncedAt,
    this.originalFileName,
    this.thumbnailBlurred = false,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'folderName': folderName,
    'displayName': displayName,
    'createdAt': createdAt.toIso8601String(),
    'lastSyncedAt': lastSyncedAt?.toIso8601String(),
    'originalFileName': originalFileName,
    'thumbnailBlurred': thumbnailBlurred,
  };

  factory VariantData.fromJson(Map<String, dynamic> j) => VariantData(
    folderName: j['folderName'] as String,
    displayName: j['displayName'] as String,
    createdAt: DateTime.parse(j['createdAt'] as String),
    lastSyncedAt: j['lastSyncedAt'] != null
        ? DateTime.parse(j['lastSyncedAt'] as String)
        : null,
    originalFileName: j['originalFileName'] as String?,
    thumbnailBlurred: (j['thumbnailBlurred'] as bool?) ?? false,
  );
}

// ── Character ──────────────────────────────────────────────────────

const String thumbnailModeFollow = 'followMainVariant';
const String thumbnailModeStatic = 'static';

class CharacterData {
  final String id;
  String name;
  final String race;
  final String gender;
  String description;
  List<String> tags;
  List<String> collectionIds;
  bool isFavourite;
  int? tierIndex;
  final DateTime createdAt;

  // Thumbnail mode: thumbnailModeFollow | thumbnailModeStatic
  String thumbnailMode;
  // Filename (relative to folderPath) used when mode is static
  String? staticThumbnailFileName;

  // Variant system
  String mainVariant;
  List<String> appliedVariants;
  List<VariantData> variants;

  // Custom border overrides — null means follow tier setting
  String? customBorderEffect;
  int? customBorderColor;

  bool thumbnailBlurred;

  // Absolute path to the character's root folder — not serialized
  final String folderPath;

  DateTime lastModifiedAt;

  CharacterData({
    required this.id,
    required this.name,
    required this.race,
    required this.gender,
    required this.folderPath,
    this.description = '',
    List<String>? tags,
    List<String>? collectionIds,
    this.isFavourite = false,
    this.tierIndex,
    DateTime? createdAt,
    DateTime? lastModifiedAt,
    this.thumbnailMode = thumbnailModeFollow,
    this.staticThumbnailFileName,
    required this.mainVariant,
    List<String>? appliedVariants,
    List<VariantData>? variants,
    this.customBorderEffect,
    this.customBorderColor,
    this.thumbnailBlurred = false,
  })  : tags = tags ?? [],
        collectionIds = collectionIds ?? [],
        appliedVariants = appliedVariants ?? [],
        variants = variants ?? [],
        createdAt = createdAt ?? DateTime.now(),
        lastModifiedAt = lastModifiedAt ?? createdAt ?? DateTime.now();

  // ── Tier ────────────────────────────────────────────────────────

  CharacterTier? get tier => CharacterTier.fromInt(tierIndex);
  set tier(CharacterTier? t) => tierIndex = t?.index;

  // ── Variant helpers ─────────────────────────────────────────────

  VariantData? get mainVariantData =>
      variants.where((v) => v.folderName == mainVariant).firstOrNull;

  VariantData? get appliedVariantData =>
      appliedVariants.isNotEmpty
          ? variants.where((v) => v.folderName == appliedVariants.first).firstOrNull
          : null;

  bool get isApplied => appliedVariants.isNotEmpty;

  bool isVariantApplied(String folderName) => appliedVariants.contains(folderName);

  DateTime? get lastSyncedAt => mainVariantData?.lastSyncedAt;
  String? get originalFileName => mainVariantData?.originalFileName;

  // ── Thumbnail resolution ─────────────────────────────────────────

  /// Thumbnail to show on character cards and wherever the character
  /// is represented as a whole.
  String? get thumbnailPath {
    if (thumbnailMode == thumbnailModeStatic &&
        staticThumbnailFileName != null) {
      final path = p.join(folderPath, staticThumbnailFileName!);
      if (File(path).existsSync()) return path;
    }
    return thumbnailForVariant(mainVariant);
  }

  /// Thumbnail for a specific variant (shown in detail screen variants list).
  String? thumbnailForVariant(String variantFolderName) {
    final variantDir = p.join(folderPath, variantFolderName);
    return _findThumbnailInFolder(variantDir);
  }

  static String? _findThumbnailInFolder(String dirPath) {
    final dir = Directory(dirPath);
    if (!dir.existsSync()) return null;
    const imageExts = {'png', 'jpg', 'jpeg', 'webp'};
    final images = dir.listSync().whereType<File>().where((f) {
      final ext = p.extension(f.path).replaceFirst('.', '').toLowerCase();
      return imageExts.contains(ext);
    }).toList();
    if (images.isEmpty) return null;
    final preferred = images.where((f) =>
        p.basenameWithoutExtension(f.path)
            .toLowerCase()
            .contains('thumbnail')).firstOrNull;
    return preferred?.path ?? images.first.path;
  }

  // ── Character file paths ─────────────────────────────────────────

  /// Absolute path to the main variant's .fhp/.mhp/etc. file.
  String? get characterFilePath => _charFileForVariant(mainVariant);

  String? charFileForVariant(String variantFolderName) =>
      _charFileForVariant(variantFolderName);

  String? _charFileForVariant(String variantFolderName) {
    final variantDir = p.join(folderPath, variantFolderName);
    return _findCharFileInFolder(variantDir);
  }

  static String? _findCharFileInFolder(String dirPath) {
    final dir = Directory(dirPath);
    if (!dir.existsSync()) return null;
    const charExts = {'fhp', 'mhp', 'fnp', 'mnp', 'fdp', 'mdp', 'fcp', 'mcp'};
    return dir.listSync().whereType<File>().where((f) {
      final ext = p.extension(f.path).replaceFirst('.', '').toLowerCase();
      return charExts.contains(ext);
    }).firstOrNull?.path;
  }

  /// PSO2 game filename for the main variant (used when copying to game folder).
  String get gameFileName {
    final v = mainVariantData;
    if (v?.originalFileName != null && v!.originalFileName!.isNotEmpty) {
      return v.originalFileName!;
    }
    final cf = characterFilePath;
    if (cf != null) return p.basename(cf);
    return '';
  }

  // ── Static helpers ────────────────────────────────────────────────

  static Map<String, String> detectRaceGender(String filePath) {
    final ext = filePath.split('.').last.toLowerCase();
    const map = {
      'fhp': {'race': 'Human',  'gender': 'Female'},
      'mhp': {'race': 'Human',  'gender': 'Male'},
      'fnp': {'race': 'Newman', 'gender': 'Female'},
      'mnp': {'race': 'Newman', 'gender': 'Male'},
      'fdp': {'race': 'Deuman', 'gender': 'Female'},
      'mdp': {'race': 'Deuman', 'gender': 'Male'},
      'fcp': {'race': 'CAST',   'gender': 'Female'},
      'mcp': {'race': 'CAST',   'gender': 'Male'},
    };
    return map[ext] ?? {'race': 'Unknown', 'gender': 'Unknown'};
  }

  static bool isValidExtension(String filePath) {
    final ext = filePath.split('.').last.toLowerCase();
    return const ['fhp', 'mhp', 'fnp', 'mnp', 'fdp', 'mdp', 'fcp', 'mcp']
        .contains(ext);
  }

  static const List<String> validExtensions = [
    'fhp', 'mhp', 'fnp', 'mnp', 'fdp', 'mdp', 'fcp', 'mcp',
  ];

  /// Generates a safe folder name: sanitised display name + 8-char UUID slice.
  static String toFolderName(String displayName, String uuid) {
    final sanitized = displayName
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_{2,}'), '_')
        .trim();
    final shortId = uuid.replaceAll('-', '').substring(0, 8);
    return '${sanitized.isEmpty ? 'character' : sanitized}_$shortId';
  }

  // ── Serialization ─────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'race': race,
    'gender': gender,
    'description': description,
    'tags': tags,
    'collectionIds': collectionIds,
    'isFavourite': isFavourite,
    'tierIndex': tierIndex,
    'createdAt': createdAt.toIso8601String(),
    'lastModifiedAt': lastModifiedAt.toIso8601String(),
    'thumbnailMode': thumbnailMode,
    'staticThumbnailFileName': staticThumbnailFileName,
    'mainVariant': mainVariant,
    'appliedVariants': appliedVariants,
    'variants': variants.map((v) => v.toJson()).toList(),
    'customBorderEffect': customBorderEffect,
    'customBorderColor': customBorderColor,
    'thumbnailBlurred': thumbnailBlurred,
  };

  factory CharacterData.fromJson(
      Map<String, dynamic> j, String folderPath) =>
      CharacterData(
        id: j['id'] as String,
        name: j['name'] as String,
        race: j['race'] as String,
        gender: j['gender'] as String,
        description: (j['description'] as String?) ?? '',
        tags: (j['tags'] as List?)?.cast<String>() ?? [],
        collectionIds: (j['collectionIds'] as List?)?.cast<String>() ?? [],
        isFavourite: (j['isFavourite'] as bool?) ?? false,
        tierIndex: j['tierIndex'] as int?,
        createdAt: DateTime.parse(j['createdAt'] as String),
        lastModifiedAt: j['lastModifiedAt'] != null
            ? DateTime.parse(j['lastModifiedAt'] as String)
            : DateTime.parse(j['createdAt'] as String),
        thumbnailMode:
            (j['thumbnailMode'] as String?) ?? thumbnailModeFollow,
        staticThumbnailFileName: j['staticThumbnailFileName'] as String?,
        mainVariant: j['mainVariant'] as String,
        appliedVariants: (j['appliedVariants'] as List?)?.cast<String>() ??
            (j['appliedVariant'] != null ? [j['appliedVariant'] as String] : []),
        variants: (j['variants'] as List?)
                ?.map((e) =>
                    VariantData.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        customBorderEffect: j['customBorderEffect'] as String?,
        customBorderColor: j['customBorderColor'] as int?,
        thumbnailBlurred: (j['thumbnailBlurred'] as bool?) ?? false,
        folderPath: folderPath,
      );
}
