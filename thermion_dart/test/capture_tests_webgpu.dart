// Headless capture tests using the WebGPU backend (Dawn) on Linux.
//
// IMPORTANT: As of Filament v1.71.5, the WebGPU backend does NOT implement
// Renderer::readPixels().  The method is inherited from the base Driver
// class and is effectively a no-op — the PixelBufferDescriptor callback
// never fires and the output buffer is always zeros.  Filament's WebGPU
// driver has a lower-level `readTextureToBuffer` method, but it is not
// wired to the public readPixels API.
//
// This file is kept as a placeholder.  When a future Filament version
// implements readPixels for WebGPU, these tests can be re-enabled.
//
// The engine-creation smoke test lives in test/webgpu_smoke_test.dart
// and continues to pass.
import 'package:test/test.dart';

void main() {
  test('WebGPU readPixels not yet implemented in Filament', () {
    // Confirmed by symbol analysis of libbackend.a:
    //   - WebGPUDriver has readTextureToBuffer but NOT readPixels
    //   - ConcreteDispatcher<WebGPUDriver>::readPixels dispatches to the
    //     base class no-op
    //   - PixelBufferDescriptor callback never fires
    //
    // Re-enable capture tests once Filament implements readPixels for
    // the WebGPU backend.
    print('WebGPU readPixels is not implemented in Filament v1.71.5 — skipping capture tests');
  }, skip: 'Awaiting Filament WebGPU readPixels implementation');
}
