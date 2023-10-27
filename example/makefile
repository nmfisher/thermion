include ../makefile

# building on MacOS, we currently just delete the macos/include 
# and macos/src directories and copy from iOS

sync-libs-macos-and-update-pods: sync-libs-macos
	pushd macos && pod update