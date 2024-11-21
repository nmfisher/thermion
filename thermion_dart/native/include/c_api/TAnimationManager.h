#pragma once

#include "APIExport.h"
#include "APIBoundaryTypes.h"

#ifdef __cplusplus
extern "C"
{
#endif

	EMSCRIPTEN_KEEPALIVE void AnimationManager_addAnimationComponent(TAnimationManager *tAnimationManager, EntityId entityId);

	EMSCRIPTEN_KEEPALIVE void AnimationManager_removeAnimationComponent(TAnimationManager *tAnimationManager, EntityId entityId);

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

	EMSCRIPTEN_KEEPALIVE void AnimationManager_addBoneAnimation(
		TAnimationManager *tAnimationManager,
		TSceneAsset *tSceneAsset,
		int skinIndex,
		int boneIndex,
		const float *const frameData,
		int numFrames,
		float frameLengthInMs,
		float fadeOutInSecs,
		float fadeInInSecs,
		float maxDelta);

	EMSCRIPTEN_KEEPALIVE EntityId AnimationManager_getBone(
		TAnimationManager *tAnimationManager,
		TSceneAsset *sceneAsset,
		int skinIndex,
		int boneIndex);

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

	EMSCRIPTEN_KEEPALIVE void AnimationManager_playAnimation(
		TAnimationManager *tAnimationManager,
		TSceneAsset *sceneAsset,
		int index,
		bool loop,
		bool reverse,
		bool replaceActive,
		float crossfade,
		float startOffset);

	EMSCRIPTEN_KEEPALIVE void AnimationManager_stopAnimation(
		TAnimationManager *tAnimationManager,
		TSceneAsset *sceneAsset,
		int index);

	// Additional methods found in implementation
	EMSCRIPTEN_KEEPALIVE float AnimationManager_getAnimationDuration(
		TAnimationManager *tAnimationManager,
		TSceneAsset *sceneAsset,
		int animationIndex);

	EMSCRIPTEN_KEEPALIVE int AnimationManager_getAnimationCount(
		TAnimationManager *tAnimationManager,
		TSceneAsset *sceneAsset);

	EMSCRIPTEN_KEEPALIVE void AnimationManager_getAnimationName(
		TAnimationManager *tAnimationManager,
		TSceneAsset *sceneAsset,
		char *const outPtr,
		int index);

	EMSCRIPTEN_KEEPALIVE int AnimationManager_getBoneCount(
		TAnimationManager *tAnimationManager,
		TSceneAsset *sceneAsset,
		int skinIndex);

	EMSCRIPTEN_KEEPALIVE void AnimationManager_getBoneNames(
		TAnimationManager *tAnimationManager,
		TSceneAsset *sceneAsset,
		const char **out,
		int skinIndex);

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

	EMSCRIPTEN_KEEPALIVE void AnimationManager_setGltfAnimationFrame(
		TAnimationManager *tAnimationManager,
		TSceneAsset *tSceneAsset,
		int animationIndex,
		int frame
	);



#ifdef __cplusplus
}
#endif
