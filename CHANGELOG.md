## 0.7.0
* `removeAsset` & `clearAssets` have been renamed `removeEntity` and `clearEntities`
* added support for parenting one entity to another
* added basic collision detection + callbacks
* added keyboard/mouse widgets + controls
* `createViewer` now `awaits` the insertion of `FilamentWidget` so you no longer need to manually defer calling until after FilamentWidget has been rendered  

## 0.6.0

* `createViewer` is no longer called by `FilamentWidget` and must be called manually at least one frame after a FilamentWidget has been inserted into the widget hierarchy.


## 0.5.0

* Replaced `isReadyForScene` Future in `FilamentController` with the `Stream<bool>` `hasViewer`. 
* Rendering is set to false when the app is hidden, inactive or paused; on resume, this will be set to the value it held prior to being hidden/inactive/paused.
