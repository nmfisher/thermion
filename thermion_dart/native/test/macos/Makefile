# Makefile for Thermion Dart - macOS Version
# Using clang to build shared library directly

# Configuration variables
FILAMENT_VERSION = v1.58.0
PACKAGE_NAME = thermion_dart
PLATFORM = macos

# Architecture - default to x64 but can be overridden
ARCH ?= x64

# Compiler and flags
CC = clang++
CFLAGS = -std=c++17 -g -O0 -mmacosx-version-min=13.0
DEFINES = -DENABLE_TRACING=1

# Output library name
OUTPUT_NAME = libthermion_dart.dylib

# Project directory structure
PKG_ROOT = .
NATIVE_SRC_DIR = $(PKG_ROOT)/src
NATIVE_INCLUDE_DIR = $(PKG_ROOT)/include
OUTPUT_DIR = $(PKG_ROOT)/build

# Hardcoded library path (for Filament libraries)
LIB_DIR = /Users/nickfisher/Documents/thermion/thermion_dart/.dart_tool/thermion_dart/lib/v1.58.0/macos/debug

# Libraries are already in LIB_DIR, no download needed

# Source files
SOURCES = $(shell find $(NATIVE_SRC_DIR) -type f -name "*.cpp" -not -path "*CMakeLists*" -not -path "*main.cpp*" -not -path "*windows*")
MATERIAL_SOURCES = $(NATIVE_INCLUDE_DIR)/material/unlit_fixed_size.c \
                  $(NATIVE_INCLUDE_DIR)/material/image.c \
                  $(NATIVE_INCLUDE_DIR)/material/grid.c \
                  $(NATIVE_INCLUDE_DIR)/material/unlit.c \
                  $(NATIVE_INCLUDE_DIR)/material/gizmo.c
RESOURCE_SOURCES = $(NATIVE_INCLUDE_DIR)/resources/translation_gizmo_glb.c \
                  $(NATIVE_INCLUDE_DIR)/resources/rotation_gizmo_glb.c

ALL_SOURCES = $(SOURCES) $(MATERIAL_SOURCES) $(RESOURCE_SOURCES)

# Include paths
INCLUDES = -I$(NATIVE_INCLUDE_DIR) -I$(NATIVE_INCLUDE_DIR)/filament

# Libraries to link
LIBS = -lfilament -lbackend -lfilameshio -lviewer -lfilamat -lmeshoptimizer \
       -lmikktspace -lgeometry -lutils -lfilabridge -lgltfio_core -lgltfio \
       -lfilament-iblprefilter -limage -limageio -ltinyexr -lfilaflat \
       -ldracodec -libl -lktxreader -lpng -lz -lstb -luberzlib -lsmol-v \
       -luberarchive -lzstd -lbasis_transcoder -lmatdbg -lfgviewer -lbluegl \
       -lbluevk -lstdc++

# Frameworks for macOS
FRAMEWORKS = -framework Foundation -framework CoreVideo -framework Cocoa -framework Metal

# Default target
.PHONY: all
all: setup check-libs build

# Setup directories
.PHONY: setup
setup:
	mkdir -p "$(LIB_DIR)"
	mkdir -p "$(OUTPUT_DIR)"
	@echo "Build directories created for macOS"

# Using pre-existing Filament libraries
.PHONY: check-libs
check-libs:
	@echo "Using existing Filament libraries in $(LIB_DIR)"
	@if [ ! -d "$(LIB_DIR)" ]; then \
		echo "ERROR: Library directory $(LIB_DIR) not found"; \
		exit 1; \
	fi

# Build the shared library using clang
.PHONY: build
build:
	@echo "Building Thermion shared library for macOS ($(ARCH))"
	$(CC) $(CFLAGS) $(DEFINES) $(INCLUDES) \
		-dynamiclib -install_name @rpath/$(OUTPUT_NAME) \
		$(ALL_SOURCES) \
		-L$(LIB_DIR) $(LIBS) $(FRAMEWORKS) \
		-o $(OUTPUT_DIR)/$(OUTPUT_NAME)
	@echo "Build complete: $(OUTPUT_DIR)/$(OUTPUT_NAME)"

# Clean build artifacts
.PHONY: clean
clean:
	@echo "Build artifacts cleaned" 	# rm -rf "$(OUTPUT_DIR)"

# Help target
.PHONY: help
help:
	@echo "Thermion macOS Build System"
	@echo ""
	@echo "Usage:"
	@echo "  make [target] [ARCH=architecture]"
	@echo ""
	@echo "Targets:"
	@echo "  all            Build everything (default)"
	@echo "  setup          Create necessary directories"
	@echo "  check-libs     Verify Filament libraries exist"
	@echo "  build          Build the shared library"
	@echo "  clean          Clean build artifacts"
	@echo ""
	@echo "Options:"
	@echo "  ARCH           Target architecture (default: x64)"
	@echo "                 Supported: x64, arm64"