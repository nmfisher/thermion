#pragma once

// glTF-only embedded clip playback API. Kept out of TAnimationManager.h so
// the core animation header stays 100% core (no glTF surface). The handle is
// created alongside a TAnimationManager and registers its clip playback
// system as a tickable on it; clips are advanced by AnimationManager_update.

#include "APIExport.h"
#include "APIBoundaryTypes.h"

#ifdef __cplusplus
extern "C"
{
#endif

	// Creates the glTF clip playback manager for [tAnimationManager] and adds
	// it to that manager's frame tick (addTickable). One handle per
	// TAnimationManager. Destroy it with GltfAnimationManager_destroy BEFORE
	// destroying the TAnimationManager.
	EMSCRIPTEN_KEEPALIVE TGltfAnimationManager *GltfAnimationManager_create(TAnimationManager *tAnimationManager);
	EMSCRIPTEN_KEEPALIVE void GltfAnimationManager_destroy(TGltfAnimationManager *tGltfAnimationManager);

	EMSCRIPTEN_KEEPALIVE bool AnimationManager_addGltfAnimationComponent(TGltfAnimationManager *tGltfAnimationManager, TSceneAsset *tSceneAsset);
	EMSCRIPTEN_KEEPALIVE bool AnimationManager_removeGltfAnimationComponent(TGltfAnimationManager *tGltfAnimationManager, TSceneAsset *tSceneAsset);

	EMSCRIPTEN_KEEPALIVE bool AnimationManager_playGltfAnimation(
		TGltfAnimationManager *tGltfAnimationManager,
		TSceneAsset *tSceneAsset,
		int index,
		bool loop,
		bool reverse,
		bool replaceActive,
		float crossfade,
		float startOffset,
		float speed);

	EMSCRIPTEN_KEEPALIVE bool AnimationManager_stopGltfAnimation(
		TGltfAnimationManager *tGltfAnimationManager,
		TSceneAsset *sceneAsset,
		int index);

	EMSCRIPTEN_KEEPALIVE float AnimationManager_getGltfAnimationDuration(
		TGltfAnimationManager *tGltfAnimationManager,
		TSceneAsset *sceneAsset,
		int animationIndex);

	EMSCRIPTEN_KEEPALIVE int AnimationManager_getGltfAnimationCount(
		TGltfAnimationManager *tGltfAnimationManager,
		TSceneAsset *sceneAsset);

	EMSCRIPTEN_KEEPALIVE void AnimationManager_getGltfAnimationName(
		TGltfAnimationManager *tGltfAnimationManager,
		TSceneAsset *sceneAsset,
		char *const outPtr,
		int index);

	EMSCRIPTEN_KEEPALIVE bool AnimationManager_setGltfAnimationTime(
		TGltfAnimationManager *tGltfAnimationManager,
		TSceneAsset *tSceneAsset,
		int animationIndex,
		float timeInSeconds
	);

#ifdef __cplusplus
}
#endif
