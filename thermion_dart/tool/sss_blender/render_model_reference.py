"""Cycles references for the post-textured normalized Burley implementation.

Blender 4.5 bssrdf_setup_radius scales BURLEY radii by 1/(4*pi).
The node radius is therefore 4*pi*d. This script targets that exact version.
No fitting of a radius to rendered Thermion results is performed.
"""
import argparse
import ctypes
import json
import math
from pathlib import Path
import struct
import sys
import zlib

import bpy
import numpy as np
from mathutils import Vector

ROOT = Path(__file__).resolve().parent
parser = argparse.ArgumentParser()
parser.add_argument('--samples', type=int, default=4096)
parser.add_argument('--sphere', action='store_true')
args = parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
OUT = ROOT / 'burley-reference'
OUT.mkdir(exist_ok=True)
lib = ctypes.CDLL(str(ROOT / ('display.dylib' if sys.platform == 'darwin' else 'display.so')))
lib.display_transform.argtypes = [ctypes.POINTER(ctypes.c_float), ctypes.c_int]

def png(path, a):
    h,w,_ = a.shape
    def chunk(kind, data):
        return struct.pack('>I',len(data))+kind+data+struct.pack('>I',zlib.crc32(kind+data)&0xffffffff)
    data=b''.join(b'\0'+row.tobytes() for row in a)
    path.write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',w,h,8,6,0,0,0))+chunk(b'IDAT',zlib.compress(data))+chunk(b'IEND',b''))

def configure(scene, size):
    scene.render.engine='CYCLES'
    scene.cycles.device='CPU'
    scene.cycles.samples=args.samples
    scene.cycles.use_denoising=False
    scene.cycles.use_adaptive_sampling=False
    scene.cycles.seed=353
    scene.cycles.max_bounces=12
    scene.render.threads_mode='FIXED'
    scene.render.threads=4
    scene.render.resolution_x=scene.render.resolution_y=size
    scene.render.resolution_percentage=100
    scene.render.filter_size=1
    scene.cycles.pixel_filter_type='BOX'
    scene.render.image_settings.file_format='OPEN_EXR'
    scene.render.image_settings.color_depth='32'
    scene.view_settings.view_transform='Standard'
    scene.view_settings.look='None'
    scene.view_settings.exposure=0
    scene.view_settings.gamma=1

def render(scene, name):
    scene.render.filepath=str(OUT/(name+'.exr'))
    bpy.ops.render.render(write_still=True)
    im=bpy.data.images.load(scene.render.filepath,check_existing=False)
    w,h=im.size
    values=np.empty(w*h*4,dtype=np.float32)
    im.pixels.foreach_get(values)
    linear=values.reshape(h,w,4)[::-1].copy()
    if w == 128:
        png(OUT/(name+'_linear.png'),np.rint(np.clip(linear,0,1)*255).astype(np.uint8))
    lib.display_transform(values.ctypes.data_as(ctypes.POINTER(ctypes.c_float)),w*h)
    png(OUT/(name+'.png'),np.rint(np.clip(values.reshape(h,w,4)[::-1],0,1)*255).astype(np.uint8))
    bpy.data.images.remove(im)
    (OUT/(name+'.json')).write_text(json.dumps(dict(blender=bpy.app.version_string,
        samples=args.samples,denoising=False,profile='Normalized Burley, node radius = 4*pi*d',
        width=w,height=h,center_row=linear[h//2,:,:3].tolist()),indent=2))
    print('FINISHED',name,flush=True)

assert bpy.app.version[:2]==(4,5), 'Radius mapping is verified against Cycles 4.5 source'
if args.sphere:
    bpy.ops.wm.open_mainfile(filepath=str(ROOT/'sss_comparison.blend'))
    scene=bpy.context.scene
    configure(scene,640)
    bsdf=bpy.data.materials['Textured dielectric · random walk'].node_tree.nodes.get('Principled BSDF')
    bsdf.subsurface_method='BURLEY'
    bsdf.inputs['Subsurface Radius'].default_value=tuple(4*math.pi*x for x in (1,.5,.25))
    for name,d in [('sphere_off',0),('sphere_d0.6mm',.0006),('sphere_d1.2mm',.0012)]:
        bsdf.inputs['Subsurface Weight'].default_value=float(d>0)
        bsdf.inputs['Subsurface Scale'].default_value=d or .0006
        render(scene,name)
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'sphere-burley.blend'))
else:
    for texture in (True,False):
        bpy.ops.wm.read_factory_settings(use_empty=True)
        scene=bpy.context.scene
        configure(scene,128)
        world=bpy.data.worlds.new('No ambient illumination')
        world.use_nodes=True
        world.node_tree.nodes.get('Background').inputs['Strength'].default_value=0
        scene.world=world
        # A closed thick slab: the measured top is z=0; its sides and bottom
        # lie well outside the 16d support of the measured central pixels.
        bpy.ops.mesh.primitive_cube_add(size=1,location=(0,0,-.5))
        receiver=bpy.context.object
        receiver.name='Uniform slab' if not texture else 'Textured slab'
        receiver.scale=(3.2,3.2,1)
        bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
        material=bpy.data.materials.new('Reference material')
        material.use_nodes=True
        nodes=material.node_tree.nodes
        links=material.node_tree.links
        nodes.clear()
        output=nodes.new('ShaderNodeOutputMaterial')
        diffuse=nodes.new('ShaderNodeBsdfDiffuse')
        sss=nodes.new('ShaderNodeSubsurfaceScattering')
        sss.falloff='BURLEY'
        for node in (diffuse,sss):
            node.inputs['Color'].default_value=(.5,.5,.5,1)
        if texture:
            geometry=nodes.new('ShaderNodeNewGeometry')
            xyz=nodes.new('ShaderNodeSeparateXYZ')
            greater=nodes.new('ShaderNodeMath')
            greater.operation='GREATER_THAN'
            greater.inputs[1].default_value=0
            color=nodes.new('ShaderNodeMixRGB')
            color.inputs[1].default_value=(0,0,0,1)
            color.inputs[2].default_value=(.5,.5,.5,1)
            links.new(geometry.outputs['Position'],xyz.inputs[0])
            links.new(xyz.outputs['X'],greater.inputs[0])
            links.new(greater.outputs[0],color.inputs[0])
            for node in (diffuse,sss):links.new(color.outputs[0],node.inputs['Color'])
        receiver.data.materials.append(material)
        if not texture:
            bpy.ops.mesh.primitive_plane_add(size=6.4,location=(-4.2,0,1))
            blocker=bpy.context.object
            blocker.name='Off-camera shadow caster'
            black=bpy.data.materials.new('Absorbing blocker')
            black.use_nodes=True
            b=black.node_tree.nodes.get('Principled BSDF')
            b.inputs['Base Color'].default_value=(0,0,0,1)
            b.inputs['Specular IOR Level'].default_value=0
            blocker.data.materials.append(black)
        sun=bpy.data.lights.new('Directional reference','SUN')
        sun.energy=100000/(1.2*16**2*125)
        sun.angle=0
        light=bpy.data.objects.new('Sun',sun)
        scene.collection.objects.link(light)
        light.rotation_euler=Vector((0 if texture else 1,0,-1)).to_track_quat('-Z','Y').to_euler()
        camera=bpy.data.cameras.new('Reference camera')
        camera.sensor_fit='VERTICAL'
        camera.sensor_height=32
        camera.lens=16
        camera.clip_start=.01
        camera.clip_end=10
        eye=bpy.data.objects.new('Camera',camera)
        scene.collection.objects.link(eye)
        eye.location=(0,0,.4)
        scene.camera=eye
        for ortho in (False,True):
            camera.type='ORTHO' if ortho else 'PERSP'
            camera.ortho_scale=.8
            for name,d in [('off',0),('d6.25mm',.00625),('d12.5mm',.0125)]:
                for link in list(output.inputs['Surface'].links):links.remove(link)
                if d:
                    sss.inputs['Radius'].default_value=(4*math.pi*d,)*3
                    sss.inputs['Scale'].default_value=1
                    links.new(sss.outputs[0],output.inputs['Surface'])
                else:links.new(diffuse.outputs[0],output.inputs['Surface'])
                render(scene,f'{"texture" if texture else "shadow"}_{str(ortho).lower()}_{name}')
        bpy.ops.wm.save_as_mainfile(filepath=str(OUT/f'{"texture" if texture else "shadow"}.blend'))
