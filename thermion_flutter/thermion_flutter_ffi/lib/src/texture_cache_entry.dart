class TextureCacheEntry {
  final int flutterId;
  final int hardwareId;
  final DateTime creationTime;
  DateTime? removalTime;
  bool inUse;

  TextureCacheEntry(this.flutterId, this.hardwareId,
      {this.removalTime, this.inUse = true})
      : creationTime = DateTime.now();
}