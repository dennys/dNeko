import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import '../models/animation_definition.dart';
import '../models/animal_resource.dart';

class AnimationLoader {
  /// 載入動畫定義（自動判斷內建 or 已下載）
  Future<AnimalAnimationDefinition> load(AnimalResource resource) async {
    return resource.isBuiltIn
        ? _loadFromAssets(resource.animalId)
        : _loadFromFile(resource.localFolderPath);
  }

  Future<AnimalAnimationDefinition> _loadFromAssets(String animalId) async {
    final jsonStr = await rootBundle.loadString(
      'assets/animals/$animalId/animation.json',
    );
    return AnimalAnimationDefinition.fromJson(jsonDecode(jsonStr));
  }

  Future<AnimalAnimationDefinition> _loadFromFile(String folderPath) async {
    final file = File('$folderPath/animation.json');

    if (!await file.exists()) {
      throw FileSystemException('找不到動畫描述檔', file.path);
    }

    final jsonStr = await file.readAsString();
    return AnimalAnimationDefinition.fromJson(jsonDecode(jsonStr));
  }

  /// 取得圖片 ImageProvider（自動判斷來源）
  ImageProvider getFrameImage(AnimalResource resource, String frameName) {
    if (resource.isBuiltIn) {
      return AssetImage('assets/animals/${resource.animalId}/$frameName.png');
    }
    return FileImage(File('${resource.localFolderPath}/$frameName.png'));
  }
}