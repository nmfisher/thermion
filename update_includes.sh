FILAMENT_SRCIDR=/cygdrive/c/Users/nickh/Documents/Projects/filament
FILAMENT_PLUGIN_SRCDIR=

cp -R /cygdrive/c/Users/nickh/Documents/Projects/polyvox/polyvox_filament/example/build/polyvox_filament/intermediates/merged_native_libs/release/out/lib/ /cygdrive/c/Users/nickh/Documents/Projects/polyvox/polyvox_filament/android/src/main/notjniLibs/
cp -R $FILAMENT_INCLUDE_DIRlibs/gltfio/include/* /cygdrive/c/Users/nickh/Documents/Projects/polyvox/polyvox_filament/ios/include/
cp -R $FILAMENT_INCLUDE_DIRlibs/utils/include/* /cygdrive/c/Users/nickh/Documents/Projects/polyvox/polyvox_filament/ios/include/
cp -R $FILAMENT_INCLUDE_DIRlibs/math/include/* /cygdrive/c/Users/nickh/Documents/Projects/polyvox/polyvox_filament/ios/include/
cp -R $FILAMENT_INCLUDE_DIRfilament/backend/include/backend/ /cygdrive/c/Users/nickh/Documents/Projects/polyvox/polyvox_filament/ios/include/
cp -R $FILAMENT_INCLUDE_DIRlibs/filabridge/include/filament/* /cygdrive/c/Users/nickh/Documents/Projects/polyvox/polyvox_filament/ios/include/filament/
find $FILAMENT_INCLUDE_DIR -type d -name camutils
cp -R $FILAMENT_INCLUDE_DIRlibs/camutils/* /cygdrive/c/Users/nickh/Documents/Projects/polyvox/polyvox_filament/ios/include/
cp -R $FILAMENT_INCLUDE_DIRthird_party/robin-map/tsl /cygdrive/c/Users/nickh/Documents/Projects/polyvox/polyvox_filament/ios/include/
cp $FILAMENT_INCLUDE_DIRthird_party/cgltf/cgltf.h /cygdrive/c/Users/nickh/Documents/Projects/polyvox/polyvox_filament/ios/include/
cp $FILAMENT_INCLUDE_DIRthird_party/hat-trie/tsl/htrie_map.h /cygdrive/c/Users/nickh/Documents/Projects/polyvox/polyvox_filament/ios/include/trie/
cp $FILAMENT_INCLUDE_DIRthird_party/hat-trie/tsl/* /cygdrive/c/Users/nickh/Documents/Projects/polyvox/polyvox_filament/ios/include/trie/
cp -R $FILAMENT_INCLUDE_DIRthird_party/hat-trie/tsl/* /cygdrive/c/Users/nickh/Documents/Projects/polyvox/polyvox_filament/ios/include/trie/
cp -R $FILAMENT_INCLUDE_DIRlibs/image/include/* /cygdrive/c/Users/nickh/Documents/Projects/polyvox/polyvox_filament/ios/include/
cp -R $FILAMENT_INCLUDE_DIRlibs/imageio/include/* /cygdrive/c/Users/nickh/Documents/Projects/polyvox/polyvox_filament/ios/include/
cp -R $FILAMENT_INCLUDE_DIRandroid/common /cygdrive/c/Users/nickh/Documents/Projects/polyvox/polyvox_filament/ios/include/
