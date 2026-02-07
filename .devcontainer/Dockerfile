FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# System dependencies for Flutter Linux desktop + Vulkan/EGL development
RUN apt-get update && apt-get install -y \
    # Build essentials
    git curl wget unzip xz-utils zip \
    build-essential cmake ninja-build pkg-config \
    # Clang/LLVM toolchain (required by thermion_dart native build)
    clang lld libc++-dev libc++abi-dev libclang-dev \
    # Flutter Linux desktop dependencies
    libgtk-3-dev \
    # EGL/GL for texture interop
    libegl1-mesa-dev libgl1-mesa-dev libgles2-mesa-dev \
    # Vulkan headers and loader
    libvulkan-dev vulkan-tools \
    # DRM headers for drm_fourcc.h
    libdrm-dev \
    # Misc
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Reuse the existing ubuntu user (UID 1000) so bind mounts work with podman --userns=keep-id
RUN usermod -l developer -d /home/developer -m ubuntu && \
    groupmod -n developer ubuntu
USER developer
WORKDIR /home/developer

# Install Flutter SDK directly (no fvm needed in container)
RUN git clone https://github.com/flutter/flutter.git -b stable --depth 1 /home/developer/flutter

ENV PATH="/home/developer/flutter/bin:/home/developer/flutter/bin/cache/dart-sdk/bin:${PATH}"

# Precache Linux desktop artifacts and disable analytics
RUN flutter config --no-analytics && \
    flutter precache --linux && \
    dart --disable-analytics && \
    flutter doctor -v

WORKDIR /workspace
