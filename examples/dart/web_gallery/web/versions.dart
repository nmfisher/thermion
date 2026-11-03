import 'package:web/web.dart';

/// The Thermion release this gallery was built from, injected at compile time
/// by `dart compile wasm -DTHERMION_VERSION=<version>` (see deploy.yml).
/// Falls back to 'dev' when compiled without the define (e.g. local builds).
const _kThermionVersion = String.fromEnvironment(
  'THERMION_VERSION',
  defaultValue: 'dev',
);

/// The Filament release bundled with this build. Kept in sync by hand with
/// thermion_dart/lib/filament_version.dart (generated from filament.version);
/// the gallery only displays it, so a stale value is cosmetic, not functional.
const _kFilamentVersion = String.fromEnvironment(
  'FILAMENT_VERSION',
  defaultValue: 'v1.77.2',
);

/// Populate the bottom-right version badge in index.html.
///
/// In embed mode (docs-site showcase iframes) the badge is hidden by CSS so it
/// doesn't duplicate the docs header; the standalone gallery page shows it.
void installVersionBadge() {
  final el = document.getElementById('version-badge');
  if (el == null) return;
  el.textContent = 'Thermion v$_kThermionVersion · Filament $_kFilamentVersion';
  el.setAttribute('title', 'Built from Thermion v$_kThermionVersion');
}
