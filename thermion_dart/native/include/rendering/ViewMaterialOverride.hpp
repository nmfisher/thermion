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
/// render those shared entities with their normal materials. Passing null
/// [engine] or [materialInstance] unregisters [view].
void registerViewMaterialOverride(
    filament::View *view,
    filament::Engine *engine,
    filament::MaterialInstance *materialInstance);

/// Removes any material override registered for [view].
void unregisterViewMaterialOverride(const filament::View *view);

/// Renders [view] with its registered material override, if any.
void renderViewWithMaterialOverride(
    filament::Renderer *renderer,
    filament::View *view);

/// Renders standalone [view] with its registered material override, if any.
void renderStandaloneViewWithMaterialOverride(
    filament::Renderer *renderer,
    filament::View *view);

} // namespace thermion
