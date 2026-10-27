const assert = require('node:assert/strict');
const create = require(process.argv[2]);

create().then(module => {
  let completed = false;
  const callback = module.addFunction(id => {
    assert.equal(id, 33);
    completed = true;
  }, 'vi');
  // No Engine, RenderThread or DOM exists. The normal worker-mode render()
  // entry point must complete immediately without touching any of them.
  module._RenderManager_renderRenderThread(0, 0n, 33, callback);
  assert.equal(completed, true);
  module.removeFunction(callback);
  console.log('PASS: worker-mode render call completes without dispatch or drawing');
  process.exit(0);
}).catch(error => {
  console.error(error);
  process.exit(1);
});
