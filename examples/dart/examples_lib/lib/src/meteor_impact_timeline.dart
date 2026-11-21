import 'dart:math' as math;

/// Pure timing model: contact stays sharp while its visual layers overlap.
class MeteorImpactFrame {
  static const contactTime = 1.35;
  static const duration = 6.0;
  final double cycle, age, flight, penetration;
  final double body, trail, flash, crater, dust, light, fade;

  MeteorImpactFrame._(
      this.cycle,
      this.age,
      this.flight,
      this.penetration,
      this.body,
      this.trail,
      this.flash,
      this.crater,
      this.dust,
      this.light,
      this.fade);

  static double ease(double a, double b, double t) {
    final u = ((t - a) / (b - a)).clamp(0.0, 1.0);
    return u * u * (3 - 2 * u);
  }

  factory MeteorImpactFrame.at(double time) {
    final cycle = time % duration;
    final age = math.max(0.0, cycle - contactTime);
    final u = ((cycle - .2) / (contactTime - .2)).clamp(0.0, 1.0);
    // Accelerate into contact, then decelerate underground without a stop.
    final flight = .4 * u + .6 * u * u;
    final penetration =
        (1.6 / (contactTime - .2)) * (1 - math.exp(-12 * age)) / 12;
    final fade = 1 - ease(5.0, 5.95, cycle);
    final flash = ease(0, .09, age);
    return MeteorImpactFrame._(
        cycle,
        age,
        flight,
        penetration,
        1 - ease(.025, .3, age),
        ease(.15, .45, cycle) * (1 - ease(.035, .42, age)),
        flash,
        ease(.015, .62, age) * fade,
        ease(.055, .48, age) * (1 - ease(2.35, 4.4, age)),
        flash * math.exp(-age * 2.8),
        fade);
  }
}
