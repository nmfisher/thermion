import '../lib/src/meteor_impact_timeline.dart';

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

void main() {
  final before = MeteorImpactFrame.at(1.34);
  check(
      before.body == 1 &&
          before.crater == 0 &&
          before.flash == 0 &&
          before.dust == 0 &&
          before.light == 0,
      'Impact started before contact');
  final overlap = MeteorImpactFrame.at(1.47);
  check(
      overlap.body > .5 &&
          overlap.trail > .5 &&
          overlap.flash > .9 &&
          overlap.crater > 0 &&
          overlap.dust > 0,
      'Impact layers must overlap');
  final settled = MeteorImpactFrame.at(2.1);
  check(
      settled.body == 0 &&
          settled.trail == 0 &&
          settled.crater == 1 &&
          settled.dust == 1,
      'Aftermath must take over from the meteor');
  final end = MeteorImpactFrame.at(5.99);
  check(end.crater == 0 && end.dust == 0 && end.fade == 0,
      'Reset must finish before loop boundary');
  double path(double t) {
    final f = MeteorImpactFrame.at(t);
    return f.flight + f.penetration;
  }

  const contact = MeteorImpactFrame.contactTime, epsilon = .0001;
  final leftSpeed = (path(contact) - path(contact - epsilon)) / epsilon;
  final rightSpeed = (path(contact + epsilon) - path(contact)) / epsilon;
  check(
      (leftSpeed - rightSpeed).abs() < .003, 'Discontinuous contact velocity');
  var previous = MeteorImpactFrame.at(0);
  for (var i = 1; i < 6000; i++) {
    final f = MeteorImpactFrame.at(i / 1000);
    for (final v in [
      f.body,
      f.trail,
      f.flash,
      f.crater,
      f.dust,
      f.light,
      f.fade
    ]) {
      check(v.isFinite && v >= 0 && v <= 1, 'Envelope outside [0,1] at $i ms');
    }
    check((f.crater - previous.crater).abs() < .003,
        'Discontinuous crater growth');
    check((f.trail - previous.trail).abs() < .01, 'Discontinuous trail fade');
    previous = f;
  }
  print(
      'Meteor timeline checks passed (6000 samples, overlap, velocity, reset).');
}
