#pragma once

#include "APIExport.h"
#include "APIBoundaryTypes.h"

// glTF embedded clip playback lives in TGltfAnimationManager.h
// (AnimationManager_*GltfAnimation*, keyed on a TGltfAnimationManager handle);
// this header stays 100% core.

#ifdef __cplusplus
extern "C"
{
#endif
	
	EMSCRIPTEN_KEEPALIVE TAnimationManager *AnimationManager_create(TEngine *tEngine);
	EMSCRIPTEN_KEEPALIVE void AnimationManager_destroy(TAnimationManager *tAnimationManager);

	EMSCRIPTEN_KEEPALIVE void AnimationManager_update(TAnimationManager *tAnimationManager, uint64_t frameTimeInNanos);

	EMSCRIPTEN_KEEPALIVE void AnimationManager_addMorphAnimationComponent(TAnimationManager *tAnimationManager, EntityId entityId);
	EMSCRIPTEN_KEEPALIVE void AnimationManager_removeMorphAnimationComponent(TAnimationManager *tAnimationManager, EntityId entityId);
	EMSCRIPTEN_KEEPALIVE bool AnimationManager_addBoneAnimationComponent(TAnimationManager *tAnimationManager, TSceneAsset *tSceneAsset);
	EMSCRIPTEN_KEEPALIVE bool AnimationManager_removeBoneAnimationComponent(TAnimationManager *tAnimationManager, TSceneAsset *tSceneAsset);

	EMSCRIPTEN_KEEPALIVE bool AnimationManager_setMorphAnimation(
		TAnimationManager *tAnimationManager,
		EntityId entityId,
		const float *const morphData,
		const uint32_t *const morphIndices,
		int numMorphTargets,
		int numFrames,
		float frameLengthInMs);

	EMSCRIPTEN_KEEPALIVE bool AnimationManager_clearMorphAnimation(TAnimationManager *tAnimationManager, EntityId entityId);

	EMSCRIPTEN_KEEPALIVE void AnimationManager_resetToRestPose(TAnimationManager *tAnimationManager, TSceneAsset *sceneAsset);

	EMSCRIPTEN_KEEPALIVE bool AnimationManager_addBoneAnimation(
		TAnimationManager *tAnimationManager,
		TSceneAsset *tSceneAsset,
		int skinIndex,
		int boneIndex,
		const float *const frameData,
		int numFrames,
		float frameLengthInMs,
		float fadeOutInSecs,
		float fadeInInSecs,
		float maxDelta, 
		bool loop);

	EMSCRIPTEN_KEEPALIVE void AnimationManager_getRestLocalTransforms(
		TAnimationManager *tAnimationManager,
		TSceneAsset *sceneAsset,
		int skinIndex,
		float *const out,
		int numBones);

	EMSCRIPTEN_KEEPALIVE void AnimationManager_getInverseBindMatrix(
		TAnimationManager *tAnimationManager,
		TSceneAsset *sceneAsset,
		int skinIndex,
		int boneIndex,
		float *const out);

	EMSCRIPTEN_KEEPALIVE int AnimationManager_getMorphTargetNameCount(
		TAnimationManager *tAnimationManager,
		TSceneAsset *sceneAsset,
		EntityId childEntity);

	EMSCRIPTEN_KEEPALIVE void AnimationManager_getMorphTargetName(
		TAnimationManager *tAnimationManager,
		TSceneAsset *sceneAsset,
		EntityId childEntity,
		char *const outPtr,
		int index);

	EMSCRIPTEN_KEEPALIVE bool AnimationManager_updateBoneMatrices(
		TAnimationManager *tAnimationManager,
		TSceneAsset *sceneAsset);


	EMSCRIPTEN_KEEPALIVE bool AnimationManager_setMorphTargetWeights(
		TAnimationManager *tAnimationManager,
		EntityId entityId,
		const float *const morphData,
		int numWeights);


#ifdef __cplusplus
}
#endif
