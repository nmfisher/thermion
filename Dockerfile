FROM ubuntu:22.04

# Set non-interactive mode for apt
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies and add LLVM repository
RUN apt-get update && apt-get install -y \
    git \
    build-essential \
    cmake \
    ninja-build \
    libgl1-mesa-dev \
    libc++-dev \
    libc++abi-dev \
    libsdl2-dev \
    libxi-dev \
    libtbb-dev \
    libassimp-dev \
    python3 \
    python3-pip \
    curl \
    wget \
    software-properties-common \
    lsb-release \
    && rm -rf /var/lib/apt/lists/*

# Add LLVM repository and install Clang 16
RUN wget -O - https://apt.llvm.org/llvm-snapshot.gpg.key | apt-key add - \
    && add-apt-repository "deb http://apt.llvm.org/jammy/ llvm-toolchain-jammy-16 main" \
    && apt-get update \
    && apt-get install -y \
    clang-16 \
    clang++-16 \
    libc++-16-dev \
    libc++abi-16-dev \
    && rm -rf /var/lib/apt/lists/*

# Set Clang 16 as default
RUN update-alternatives --install /usr/bin/clang clang /usr/bin/clang-16 100 \
    && update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-16 100

# Set environment variables for Clang
ENV CC=clang-16
ENV CXX=clang++-16

# Set working directory
WORKDIR /opt

# Clone the filament repository
RUN git clone https://github.com/google/filament.git

# Change to filament directory
WORKDIR /opt/filament

# Checkout the specific version
RUN git checkout v1.58.0

# Add CMAKE_POSITION_INDEPENDENT_CODE setting after project() line
RUN sed -i '/^project(/a set(CMAKE_POSITION_INDEPENDENT_CODE ON)\nadd_compile_definitions(GLTFIO_USE_FILESYSTEM=0)' CMakeLists.txt
RUN sed -i -e '/^#define GLTFIO_USE_FILESYSTEM 1$/i\
#ifndef GLTFIO_USE_FILESYSTEM' -e '/^#define GLTFIO_USE_FILESYSTEM 1$/a\
#endif' libs/gltfio/src/FFilamentAsset.h

# Make build script executable
RUN chmod +x build.sh

# Run the build commands
RUN ./build.sh -l -i -f -p desktop release
RUN ./build.sh -l -i -f -p desktop release zstd
RUN ./build.sh -l -i -f -p desktop release tinyexr
RUN ./build.sh -l -i -f -p desktop release imageio
RUN zip -r filament-v1.58.0-linux-release.zip /opt/filament/out/release/filament/lib/x86_64/*.a /opt/filament/out/cmake-release/third_party/tinyexr/tnt/libtinyexr.a /opt/filament/out/cmake-release/libs/imageio/libimageio.a 
# Set the working directory to the build output
WORKDIR /opt/filament/out/release

CMD ["/bin/bash"]
