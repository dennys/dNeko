import '../models/animal_resource.dart';

abstract interface class IAnimalRepository {
  Future<List<AnimalResource>> getAll();
  Future<List<AnimalResource>> getDownloaded();
  Future<AnimalResource?> getById(String animalId);

  /// 该用哪份素材：DB 優先（下載過/改過的），沒這一列才退回內建。
  /// 预览塊舆 overlay 共用，两边才不会对不起来。
  Future<AnimalResource?> resolveResource(String animalId);
  Future<void> upsert(AnimalResource resource);
  Future<void> delete(String animalId);
}