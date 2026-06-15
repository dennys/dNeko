import '../models/animal_resource.dart';

abstract interface class IAnimalRepository {
  Future<List<AnimalResource>> getAll();
  Future<List<AnimalResource>> getDownloaded();
  Future<AnimalResource?> getById(String animalId);
  Future<void> upsert(AnimalResource resource);
  Future<void> delete(String animalId);
}