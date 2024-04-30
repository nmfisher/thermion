LDFLAGS:=-lfilament -lbackend -lfilameshio -lviewer -lfilamat -lgeometry -lutils -lfilabridge -lgltfio_core -lfilament-iblprefilter -limage -limageio -ltinyexr -lgltfio_core -lfilaflat -ldracodec -libl -lktxreader -lpng -lz -lstb -luberzlib -lsmol-v -luberarchive -lzstd -lvkshaders -lbluegl -lbluevk -lbasis_transcoder -lmeshoptimizer -L../macos/lib -framework CoreFoundation -framework Foundation -framework CoreVideo -framework Metal -framework QuartzCore -framework Cocoa

clean:
	rm ./out/test
run: build
	./out/test
build: cpp/test.cpp
	mkdir -p out
	clang++ -I../ios/include/filament -I../ios/include/ cpp/test.cpp ../macos/src/SceneManager.cpp --std=c++17 $(LDFLAGS)  -o out/test

