## 0.6.0

* `createViewer` is no longer called by `FilamentWidget` and must be called manually at least one frame after a FilamentWidget has been inserted into the widget hierarchy.


## 0.5.0

* Replaced `isReadyForScene` Future in `FilamentController` with the `Stream<bool>` `hasViewer`. 
* Rendering is set to false when the app is hidden, inactive or paused; on resume, this will be set to the value it held prior to being hidden/inactive/paused.
