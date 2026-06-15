class AnimalResource {
  final int? id;
  final String animalId;
  final String displayName;
  final String localFolderPath; // 下載後的本地資料夾
  final String version;
  final bool isDownloaded;
  final bool isBuiltIn; // 是否內建（assets）
  final DateTime updatedAt;

  const AnimalResource({
    this.id,
    required this.animalId,
    required this.displayName,
    required this.localFolderPath,
    required this.version,
    required this.isDownloaded,
    required this.isBuiltIn,
    required this.updatedAt,
  });

  AnimalResource copyWith({
    bool? isDownloaded,
    String? version,
    String? localFolderPath,
  }) =>
      AnimalResource(
        id: id,
        animalId: animalId,
        displayName: displayName,
        localFolderPath: localFolderPath ?? this.localFolderPath,
        version: version ?? this.version,
        isDownloaded: isDownloaded ?? this.isDownloaded,
        isBuiltIn: isBuiltIn,
        updatedAt: DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'animal_id': animalId,
        'display_name': displayName,
        'local_folder_path': localFolderPath,
        'version': version,
        'is_downloaded': isDownloaded ? 1 : 0,
        'is_built_in': isBuiltIn ? 1 : 0,
        'updated_at': updatedAt.toIso8601String(),
      };

  factory AnimalResource.fromMap(Map<String, dynamic> map) => AnimalResource(
        id: map['id'] as int?,
        animalId: map['animal_id'] as String,
        displayName: map['display_name'] as String,
        localFolderPath: map['local_folder_path'] as String,
        version: map['version'] as String,
        isDownloaded: (map['is_downloaded'] as int) == 1,
        isBuiltIn: (map['is_built_in'] as int) == 1,
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );
}