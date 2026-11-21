import 'package:flutter_test/flutter_test.dart';
import 'package:thermion_examples_lib/examples_lib.dart';

void main() {
  test('cadence uses elapsed intervals and rejects invalid samples', () {
    final samples = FrameSamples(capacity: 3);
    expect(samples.summary()['samples'], 0);
    for (final value in [10.0, 20.0, 30.0, double.nan, -1.0, 0.0]) {
      samples.add(value);
    }
    expect(samples.summary()['mean_ms'], 20);
    expect(samples.summary()['hz'], 50);
    expect(samples.summary()['p95_ms'], 30);
    samples.add(40);
    expect(samples.summary()['mean_ms'], 30);
    expect(samples.summary()['p50_ms'], 30);
    expect(samples.summary()['max_ms'], 40);
    samples.clear();
    samples.add(16);
    expect(samples.summary()['samples'], 1);
    expect(samples.summary()['mean_ms'], 16);
  });

  test('clock does not jump after pause or backgrounding', () {
    final clock = ShowcaseClock()..reset(to: 0);
    clock.tick(10);
    expect(clock.tick(10.05), closeTo(.05, 1e-9));
    clock.paused = true;
    expect(clock.tick(20), closeTo(.05, 1e-9));
    clock.paused = false;
    clock.suspend();
    expect(clock.tick(50), closeTo(.05, 1e-9));
    expect(clock.tick(50.05), closeTo(.1, 1e-9));
    clock.speed = 2;
    expect(clock.tick(50.1), closeTo(.2, 1e-9));
    expect(clock.tick(100), closeTo(.4, 1e-9));
  });
}
