import 'dart:async';
import 'dart:js_interop';

import 'package:thermion_dart/thermion_dart.dart';
import 'package:web/web.dart';

/// Connects the Effects scene's browser controls to the active Filament view.
Future<void> installEffectsControls(ThermionViewer viewer) async {
  final panel = document.getElementById('effects-controls') as HTMLElement;
  final fxaa = document.getElementById('effects-fxaa') as HTMLInputElement;
  final bloom = document.getElementById('effects-bloom') as HTMLInputElement;
  final colorGrading =
      document.getElementById('effects-color-grading') as HTMLInputElement;
  final bloomStrength =
      document.getElementById('effects-bloom-strength') as HTMLInputElement;
  final exposure =
      document.getElementById('effects-exposure') as HTMLInputElement;
  final temperature =
      document.getElementById('effects-temperature') as HTMLInputElement;
  final tint = document.getElementById('effects-tint') as HTMLInputElement;
  final contrast =
      document.getElementById('effects-contrast') as HTMLInputElement;
  final saturation =
      document.getElementById('effects-saturation') as HTMLInputElement;
  final vibrance =
      document.getElementById('effects-vibrance') as HTMLInputElement;
  final reset = document.getElementById('effects-reset') as HTMLButtonElement;

  final gradingInputs = [
    exposure,
    temperature,
    tint,
    contrast,
    saturation,
    vibrance,
  ];

  double valueOf(HTMLInputElement input) => double.tryParse(input.value) ?? 0.0;

  void updateValueLabel(HTMLInputElement input) {
    document.getElementById('${input.id}-value')!.textContent = input.value;
  }

  Timer? gradingDebounce;
  Future<void> gradingQueue = Future.value();

  Future<void> rebuildColorGrading() async {
    try {
      final builder = await viewer.view.createColorGradingBuilder();
      final next = await builder
          .quality(QualityLevel.HIGH)
          .exposure(valueOf(exposure))
          .whiteBalance(valueOf(temperature), valueOf(tint))
          .contrast(valueOf(contrast))
          .saturation(valueOf(saturation))
          .vibrance(valueOf(vibrance))
          .build();
      await builder.dispose();
      if (colorGrading.checked) {
        // The view takes ownership of the new grading and destroys the
        // previously-set one - no manual disposal of the old grading here.
        await viewer.view.setColorGrading(next);
      } else {
        // Built but never attached: the caller owns it, so dispose it.
        await next.dispose();
      }
    } catch (error, stackTrace) {
      print('Failed to update color grading: $error\n$stackTrace');
    }
  }

  void scheduleColorGrading() {
    gradingDebounce?.cancel();
    gradingDebounce = Timer(const Duration(milliseconds: 75), () {
      gradingQueue = gradingQueue.then((_) => rebuildColorGrading());
    });
  }

  fxaa.addEventListener(
      'change',
      ((Event _) {
        unawaited(viewer.setAntiAliasing(false, fxaa.checked, false));
      }).toJS);
  bloom.addEventListener(
      'change',
      ((Event _) {
        bloomStrength.disabled = !bloom.checked;
        unawaited(viewer.setBloom(bloom.checked, valueOf(bloomStrength)));
      }).toJS);
  bloomStrength.addEventListener(
      'input',
      ((Event _) {
        updateValueLabel(bloomStrength);
        unawaited(viewer.setBloom(bloom.checked, valueOf(bloomStrength)));
      }).toJS);
  colorGrading.addEventListener(
      'change',
      ((Event _) {
        for (final input in gradingInputs) {
          input.disabled = !colorGrading.checked;
        }
        gradingQueue = gradingQueue.then((_) async {
          if (colorGrading.checked) {
            await rebuildColorGrading();
          } else {
            await viewer.view.setColorGrading(null);
          }
        });
      }).toJS);
  for (final input in gradingInputs) {
    input.addEventListener(
        'input',
        ((Event _) {
          updateValueLabel(input);
          scheduleColorGrading();
        }).toJS);
  }

  Future<void> resetControls() async {
    gradingDebounce?.cancel();
    fxaa.checked = true;
    bloom.checked = true;
    bloomStrength
      ..disabled = false
      ..value = '0.30';
    colorGrading.checked = true;
    exposure.value = '0';
    temperature.value = '0';
    tint.value = '0';
    contrast.value = '1';
    saturation.value = '1';
    vibrance.value = '1';
    updateValueLabel(bloomStrength);
    for (final input in gradingInputs) {
      input.disabled = false;
      updateValueLabel(input);
    }
    await viewer.setAntiAliasing(false, true, false);
    await viewer.setBloom(true, 0.30);
    gradingQueue = gradingQueue.then((_) => rebuildColorGrading());
    await gradingQueue;
  }

  reset.addEventListener(
      'click',
      ((Event _) {
        unawaited(resetControls());
      }).toJS);

  await rebuildColorGrading();
  panel.removeAttribute('hidden');
}
