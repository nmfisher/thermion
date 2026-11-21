import 'dart:math' as math;

/// Budgets are explicit so the same presets work in Flutter and native CLI.
enum ShowcaseQuality {
  low('Low', 24, 16, 8, .65, false),
  balanced('Balanced', 48, 32, 16, .85, true),
  high('High', 96, 56, 28, 1, true);

  const ShowcaseQuality(this.label, this.auroraSamples, this.stormSamples,
      this.furShells, this.resolutionScale, this.shadows);
  final String label;
  final int auroraSamples, stormSamples, furShells;
  final double resolutionScale;
  final bool shadows;

  Map<String, Object> toJson() => {
        'name': name,
        'aurora_samples': auroraSamples,
        'storm_samples': stormSamples,
        'fur_shells': furShells,
        'resolution_scale': resolutionScale,
        'shadows': shadows,
      };
}

/// Bounded sample history. Units are milliseconds; FPS derives from the mean
/// interval, not the mean of instantaneous reciprocal FPS values.
class FrameSamples {
  FrameSamples({this.capacity = 240}) {
    if (capacity < 1) throw ArgumentError.value(capacity, 'capacity');
  }
  final int capacity;
  final List<double> _values = [];
  int _next = 0;
  int get length => _values.length;
  void clear() {
    _values.clear();
    _next = 0;
  }

  void add(double milliseconds) {
    if (!milliseconds.isFinite || milliseconds <= 0) return;
    if (_values.length < capacity) {
      _values.add(milliseconds);
    } else {
      _values[_next] = milliseconds;
    }
    _next = (_next + 1) % capacity;
  }

  Map<String, num> summary() {
    if (_values.isEmpty)
      return {
        'samples': 0,
        'mean_ms': 0,
        'p50_ms': 0,
        'p95_ms': 0,
        'max_ms': 0,
        'hz': 0
      };
    final sorted = [..._values]..sort();
    final mean = _values.reduce((a, b) => a + b) / _values.length;
    double percentile(double p) => sorted[(p * sorted.length).ceil() - 1];
    return {
      'samples': sorted.length,
      'mean_ms': mean,
      'p50_ms': percentile(.5),
      'p95_ms': percentile(.95),
      'max_ms': sorted.last,
      'hz': 1000 / mean
    };
  }
}

/// Simulation clock with no jump after pause or an application background gap.
class ShowcaseClock {
  double time = 3.2;
  double speed = 1;
  bool paused = false;
  double? _previous;
  void reset({double to = 3.2}) {
    time = to;
    _previous = null;
  }

  void suspend() {
    _previous = null;
  }

  double tick(double wallSeconds) {
    final previous = _previous;
    _previous = wallSeconds;
    if (!paused && previous != null) {
      time += math.min(.1, math.max(0.0, wallSeconds - previous)) * speed;
    }
    return time;
  }
}
