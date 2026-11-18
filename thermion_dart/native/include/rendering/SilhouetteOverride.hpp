#pragma once

namespace filament {
class Engine;
class MaterialInstance;
class Renderer;
class View;
} // namespace filament

namespace thermion {

/// Registers a single material instance to temporarily override every
/// renderable primitive in [view]'s scene while [view] renders, restoring the
/// original material instances immediately afterward so subsequent views
/// (overlay / main views) render those shared entities with their normal
/// materials. Passing null [engine] or [materialInstance] unregisters [view].
void registerSilhouetteMaterialOverride(
    filament::View *view,
    filament::Engine *engine,
    filament::MaterialInstance *materialInstance);

/// Removes any material override registered for [view].
void unregisterSilhouetteMaterialOverride(const filament::View *view);

/// Renders [view] with its registered silhouette material override, if any.
void renderViewWithSilhouetteOverride(
    filament::Renderer *renderer,
    filament::View *view);

/// Renders standalone [view] with its registered silhouette material override,
/// if any.
void renderStandaloneViewWithSilhouetteOverride(
    filament::Renderer *renderer,
    filament::View *view);

} // namespace thermion
