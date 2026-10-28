# Transform rendering goldens

These seven PNGs per platform cover the rendering tests in
`test/transform_tests.dart`. The Dart test workflow adds the matching platform's
images to the reviewed release baseline before running the existing strict
comparison. Existing release images and comparison thresholds are unchanged.

The images are copied unchanged from the Linux OpenGL, Windows SwiftShader
Vulkan and macOS Metal jobs in
[capture run 40701435392](https://github.com/nmfisher/thermion/actions/runs/40701435392),
using commit `3183477ac81e0ef4a823ddedbc1d1835c6e460e7`.

The transaction captures use the rendered cube entities. The test checks that
the rendered pixels change as well as checking each entity's local transform.

To refresh these goldens, run the full transform suite on the same CI backends,
review the captures, and include the affected platform images in the PR.
