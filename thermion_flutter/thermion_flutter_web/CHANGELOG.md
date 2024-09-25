## 0.1.0-dev.4.0

> Note: This release has breaking changes.

 - **BREAKING** **CHORE**: restructure viewer folders as libraries to only export the public interface.

## 0.1.0-dev.1.0

> Note: This release has breaking changes.

 - **FIX**: (flutter/web) use window.devicePixelRatio for viewport.
 - **FEAT**: (flutter) (web) use options to determine whether to create canvas, and set fixed position + offset.
 - **FEAT**: add ThermionFlutterOptions classes, rename interface parameter for offsetTop and ensure pixelRatio is passed to resizeTexture.
 - **BREAKING** **FEAT**: (flutter) (web) upgrade package:web dep to 1.0.0.
 - **BREAKING** **FEAT**: (web) (flutter) create canvas when createViewer is called (no longer need to manually add canvas element to web HTML).
 - **BREAKING** **FEAT**: resize canvas on web.

## 0.0.3

 - **FEAT**: allow passing assetPathPrefix to ThermionViewerWasm to account for Flutter build asset paths.
 - **FEAT**: allow passing assetPathPrefix to ThermionViewerWasm to account for Flutter build asset paths.

## 0.0.2

 - **FEAT**: allow passing assetPathPrefix to ThermionViewerWasm to account for Flutter build asset paths.

## 0.0.1+9

 - Update a dependency to the latest release.

## 0.0.1+8

 - Update a dependency to the latest release.

## 0.0.1+7

 - Update a dependency to the latest release.

## 0.0.1+6

 - Graduate package to a stable release. See pre-releases prior to this version for changelog entries.

## 0.0.1-dev.0+6

 - Update a dependency to the latest release.

## 0.0.1+5

 - Update a dependency to the latest release.

## 0.0.1+4

 - Update a dependency to the latest release.

## 0.0.1+3

 - Update a dependency to the latest release.

## 0.0.1+2

 - Update a dependency to the latest release.

## 0.0.1+1

 - **REFACTOR**: export ThermionViewerWasm for web and hide FFI/WASM version.

## 0.0.1
* First release of Dart-only package
