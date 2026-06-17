import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio_cache_interceptor_file_store/dio_cache_interceptor_file_store.dart';

class MapCacheService {
  static CacheStore? _cacheStore;

  static Future<CacheStore> get cacheStore async {
    if (_cacheStore != null) return _cacheStore!;
    
    if (kIsWeb) {
      _cacheStore = MemCacheStore();
      return _cacheStore!;
    }
    
    try {
      final directory = await getApplicationSupportDirectory();
      _cacheStore = FileCacheStore("${directory.path}/map_tiles_cache");
    } catch (e) {
      print("MapCacheService: Could not initialize file store, falling back to Memory: $e");
      _cacheStore = MemCacheStore();
    }
    return _cacheStore!;
  }
}
