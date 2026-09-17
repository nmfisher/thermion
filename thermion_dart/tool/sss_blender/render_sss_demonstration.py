"""Visible Cycles Burley demonstration: shadow teeth and a painted stripe.

Run with Blender 4.5 --background --python this_file.py.
Physical camera field width 90mm; dR = 0 / .6 / 2 mm. No denoising.
The SSS node uses the previously source-verified Cycles radius mapping 4*pi*d.
"""
import bpy, math, json, ctypes, struct, sys, zlib
import numpy as np
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parent
OUT=ROOT/'visible-demo';OUT.mkdir(exist_ok=True)
assert bpy.app.version[:2]==(4,5)
bpy.ops.wm.read_factory_settings(use_empty=True)
s=bpy.context.scene
s.render.engine='CYCLES';s.cycles.device='CPU';s.cycles.samples=1024
s.cycles.use_denoising=False;s.cycles.use_adaptive_sampling=False;s.cycles.seed=353
s.cycles.max_bounces=12;s.render.threads_mode='FIXED';s.render.threads=4
s.render.resolution_x=720;s.render.resolution_y=480;s.render.resolution_percentage=100
s.render.filter_size=1;s.cycles.pixel_filter_type='BOX'
s.render.image_settings.file_format='OPEN_EXR';s.render.image_settings.color_depth='32'
s.view_settings.view_transform='Standard';s.view_settings.look='None';s.view_settings.exposure=0;s.view_settings.gamma=1
w=bpy.data.worlds.new('Black environment');w.use_nodes=True;w.node_tree.nodes['Background'].inputs['Strength'].default_value=0;s.world=w
bpy.ops.mesh.primitive_cube_add(size=1,location=(0,0,-.05))
slab=bpy.context.object;slab.name='Pale slab with painted stripe';slab.scale=(.4,.4,.1)
bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
m=bpy.data.materials.new('Post-textured Burley');m.use_nodes=True
n=m.node_tree.nodes;n.clear();l=m.node_tree.links
out=n.new('ShaderNodeOutputMaterial');diff=n.new('ShaderNodeBsdfDiffuse');sss=n.new('ShaderNodeSubsurfaceScattering');sss.falloff='BURLEY'
# The stripe is pure albedo, explicitly shared by off and on closures.
g=n.new('ShaderNodeNewGeometry');xyz=n.new('ShaderNodeSeparateXYZ');l.new(g.outputs['Position'],xyz.inputs[0])
sub=n.new('ShaderNodeMath');sub.operation='SUBTRACT';sub.inputs[1].default_value=.019;l.new(xyz.outputs['X'],sub.inputs[0])
a=n.new('ShaderNodeMath');a.operation='ABSOLUTE';l.new(sub.outputs[0],a.inputs[0])
lt=n.new('ShaderNodeMath');lt.operation='LESS_THAN';lt.inputs[1].default_value=.0015;l.new(a.outputs[0],lt.inputs[0])
mix=n.new('ShaderNodeMixRGB');mix.inputs[1].default_value=(.65,.65,.65,1);mix.inputs[2].default_value=(.01,.01,.01,1);l.new(lt.outputs[0],mix.inputs[0])
for node in (diff,sss):l.new(mix.outputs[0],node.inputs['Color'])
sss.inputs['Scale'].default_value=1
slab.data.materials.append(m)
black=bpy.data.materials.new('Absorbing shadow stencil');black.use_nodes=True
bn=black.node_tree.nodes;bn.clear();bo=bn.new('ShaderNodeOutputMaterial');bd=bn.new('ShaderNodeBsdfDiffuse');bd.inputs['Color'].default_value=(0,0,0,1);black.node_tree.links.new(bd.outputs[0],bo.inputs[0])
def blocker(name,x0,x1,y0,y1):
 z=.06
 # Direction (1,0,-1): stencil x + z = receiving shadow x.
 bpy.ops.mesh.primitive_plane_add(size=1,location=((x0+x1)/2-z,(y0+y1)/2,z))
 obj=bpy.context.object;obj.name=name;obj.scale=(x1-x0,y1-y0,1);obj.data.materials.append(black)
blocker('Shadow: broad left region',-.4,-.008,-.4,.4)
for i,y in enumerate([-.017,0,.017]):blocker(f'Shadow finger {i}',-.009,.005,y-.003,y+.003)
light=bpy.data.lights.new('Hard directional light','SUN');light.energy=2;light.angle=0
obj=bpy.data.objects.new('Sun',light);s.collection.objects.link(obj);obj.rotation_euler=Vector((1,0,-1)).to_track_quat('-Z','Y').to_euler()
cam=bpy.data.cameras.new('90mm wide macro view');cam.type='ORTHO';cam.ortho_scale=.09;cam.clip_start=.001;cam.clip_end=2
obj=bpy.data.objects.new('Camera',cam);s.collection.objects.link(obj);obj.location=(0,0,.05);s.camera=obj
# The stencil lies behind the camera and contributes only shadows.
lib=ctypes.CDLL(str(ROOT / ('display.dylib' if sys.platform == 'darwin' else 'display.so')));lib.display_transform.argtypes=[ctypes.POINTER(ctypes.c_float),ctypes.c_int]
def png(path,a):
 h,w,_=a.shape
 def chunk(k,d):return struct.pack('>I',len(d))+k+d+struct.pack('>I',zlib.crc32(k+d)&0xffffffff)
 data=b''.join(b'\0'+r.tobytes() for r in a)
 path.write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',w,h,8,6,0,0,0))+chunk(b'IDAT',zlib.compress(data))+chunk(b'IEND',b''))
meta=[]
for name,d in [('off',0),('d0.6mm',.0006),('d2mm',.002)]:
 for link in list(out.inputs['Surface'].links):l.remove(link)
 if d:
  sss.inputs['Radius'].default_value=(4*math.pi*d,4*math.pi*d*.5,4*math.pi*d*.25);l.new(sss.outputs[0],out.inputs['Surface'])
 else:l.new(diff.outputs[0],out.inputs['Surface'])
 s.render.filepath=str(OUT/(name+'.exr'));bpy.ops.render.render(write_still=True)
 im=bpy.data.images.load(s.render.filepath,check_existing=False);width,height=im.size
 values=np.empty(width*height*4,dtype=np.float32);im.pixels.foreach_get(values)
 linear=values.reshape(height,width,4)[::-1].copy()
 meta.append(dict(name=name,diffusion_distance_mm=[d*1000,d*500,d*250],center_row_linear=linear[height//2,:,:3].tolist()))
 lib.display_transform(values.ctypes.data_as(ctypes.POINTER(ctypes.c_float)),width*height)
 png(OUT/(name+'.png'),np.rint(np.clip(values.reshape(height,width,4)[::-1],0,1)*255).astype(np.uint8));bpy.data.images.remove(im)
 print('FINISHED',name,flush=True)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'visible-sss.blend'))
(OUT/'metadata.json').write_text(json.dumps(dict(blender=bpy.app.version_string,samples=1024,denoising=False,field_width_mm=90,field_height_mm=60,paint_stripe_width_mm=3,shadow_finger_width_mm=6,display='Shared Filament ACES transform; no per-image adjustments',cases=meta),indent=2))
