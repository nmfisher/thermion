"""Create the packed 100 mm sphere used by render_model_reference.py.
Run with Blender --background --factory-startup --python create_sphere_scene.py.
Geometry, UVs, texture and lighting match Thermion's GPU demo. No render is run.
"""
import argparse, ctypes, json, math, struct, sys, time, zlib
from pathlib import Path
import bpy
import numpy as np
from mathutils import Vector

ROOT = Path(__file__).resolve().parent
parser = argparse.ArgumentParser()
parser.add_argument('--samples', type=int, default=1024)
parser.add_argument('--cases', default='off,sss_0.6mm,sss_1.2mm,sss_6mm')
parser.add_argument('--output', default='renders')
parser.add_argument('--device', default='CPU')
args = parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
out = ROOT / args.output


def write_png(path, pixels):
    a = np.ascontiguousarray(pixels, dtype=np.uint8)
    h, w, _ = a.shape
    def chunk(kind, data):
        return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind+data)&0xffffffff)
    raw = b''.join(b'\0' + row.tobytes() for row in a)
    path.write_bytes(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w,h,8,6,0,0,0)) + chunk(b'IDAT', zlib.compress(raw, 6)) + chunk(b'IEND', b''))

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.device = 'CPU'
if args.device == 'METAL':
    prefs = bpy.context.preferences.addons['cycles'].preferences
    prefs.compute_device_type = 'METAL'
    prefs.get_devices()
    found = False
    for d in prefs.devices:
        d.use = d.type == 'METAL'
        found |= d.use
        print('DEVICE', d.name, d.type, d.use, flush=True)
    if not found: raise RuntimeError('No Metal device')
    scene.cycles.device = 'GPU'
scene.cycles.samples = args.samples
scene.cycles.use_adaptive_sampling = False
scene.cycles.use_denoising = False
scene.cycles.seed = 353
scene.cycles.max_bounces = 12
scene.cycles.diffuse_bounces = 4
scene.cycles.glossy_bounces = 4
scene.render.resolution_x = scene.render.resolution_y = 640
scene.render.resolution_percentage = 100
scene.render.film_transparent = False
scene.render.filter_size = 1.0
scene.cycles.pixel_filter_type = 'BOX'
scene.view_settings.view_transform = 'Standard'
scene.view_settings.look = 'None'
scene.view_settings.exposure = 0
scene.view_settings.gamma = 1
scene.unit_settings.system = 'METRIC'
scene.unit_settings.scale_length = 1.0

# Identical 512x256 byte texture, saved as sRGB. UV v=0 is its top row in
# Thermion; Blender's image convention is handled by flipping the mesh V.
y, x = np.indices((256, 512))
dark = (x % 64 < 5) | (y % 48 < 3)
pixels = np.empty((256,512,4), np.uint8)
pixels[:,:,:3] = np.where(dark[:,:,None], [102,37,27], [222,141,104])
pixels[:,:,3] = 255
texture_path = ROOT / 'grid_srgb.png'
write_png(texture_path, pixels)
tex = bpy.data.images.load(str(texture_path), check_existing=False)
tex.colorspace_settings.name = 'sRGB'
tex.pack()

# Same lat/long vertices and triangle diagonals, welding seam and poles while
# retaining each triangle corner's original UV coordinate.
verts, mapping, uvs = [], [], []
keys = {}
for lat in range(97):
    theta = lat * math.pi / 96
    for lon in range(129):
        phi = lon * math.tau / 128
        key = (lat, 0 if lat in (0,96) else lon % 128)
        if key not in keys:
            keys[key] = len(verts)
            verts.append((0.1*math.cos(phi)*math.sin(theta), 0.1*math.cos(theta), 0.1*math.sin(phi)*math.sin(theta)))
        mapping.append(keys[key])
        uvs.append((lon/128, 1-lat/96))
faces, face_uvs = [], []
for lat in range(96):
    for lon in range(128):
        a = lat*129+lon
        b = a+129
        for tri in ([(a,a+1,b)] if lat != 0 else []) + ([(b,a+1,b+1)] if lat != 95 else []):
            faces.append(tuple(mapping[i] for i in tri))
            face_uvs.append([uvs[i] for i in tri])
mesh = bpy.data.meshes.new('Thermion sphere 96x128, closed seam')
mesh.from_pydata(verts, [], faces)
mesh.update()
uv = mesh.uv_layers.new(name='ThermionUV')
for poly, coords in zip(mesh.polygons, face_uvs):
    poly.use_smooth = True
    for loop, coord in zip(poly.loop_indices, coords): uv.data[loop].uv = coord
mesh.normals_split_custom_set_from_vertices([tuple(Vector(p).normalized()) for p in verts])
ball = bpy.data.objects.new('Diagnostic sphere · radius 100 mm', mesh)
scene.collection.objects.link(ball)

mat = bpy.data.materials.new('Textured dielectric · random walk')
mat.use_nodes = True
bsdf = mat.node_tree.nodes.get('Principled BSDF')
bsdf.subsurface_method = 'RANDOM_WALK'
bsdf.inputs['Roughness'].default_value = 0.25
bsdf.inputs['Metallic'].default_value = 0
bsdf.inputs['IOR'].default_value = 1.5
bsdf.inputs['Specular IOR Level'].default_value = 0.5
bsdf.inputs['Subsurface Radius'].default_value = (1, 0.5, 0.25)
if 'Subsurface IOR' in bsdf.inputs: bsdf.inputs['Subsurface IOR'].default_value = 1.4
bsdf.inputs['Subsurface Anisotropy'].default_value = 0
texnode = mat.node_tree.nodes.new('ShaderNodeTexImage')
texnode.image = tex
texnode.interpolation = 'Linear'
texnode.extension = 'REPEAT'
mat.node_tree.links.new(texnode.outputs['Color'], bsdf.inputs['Base Color'])
ball.data.materials.append(mat)

camera = bpy.data.cameras.new('28 mm, 24 mm vertical sensor')
camera.lens = 28
camera.sensor_fit = 'VERTICAL'
camera.sensor_height = 24
camera.clip_start = 0.001
camera.clip_end = 100
camera_obj = bpy.data.objects.new('Matched camera', camera)
scene.collection.objects.link(camera_obj)
camera_obj.location = (0,0,0.38)
camera_obj.rotation_euler = (Vector((0,0,0))-camera_obj.location).to_track_quat('-Z','Y').to_euler()
scene.camera = camera_obj
sun = bpy.data.lights.new('Matched sun · pre-exposed radiance', 'SUN')
sun.energy = 100000/(1.2*16**2*125)
sun.color = (1,0.941859,0.992290)
sun.angle = math.radians(2*0.545)
sun_obj = bpy.data.objects.new('Matched sun', sun)
scene.collection.objects.link(sun_obj)
sun_obj.rotation_euler = Vector((-0.6,-0.4,-1)).to_track_quat('-Z','Y').to_euler()

# The colored Filament skybox does not light the object. A camera-ray-only world
# reproduces it without accidentally adding environment illumination to Cycles.
world = bpy.data.worlds.new('Camera-only background, no IBL')
world.use_nodes = True
nodes, links = world.node_tree.nodes, world.node_tree.links
nodes.clear()
lightpath = nodes.new('ShaderNodeLightPath')
background = nodes.new('ShaderNodeBackground')
background.inputs['Color'].default_value = (0.025,0.03,0.045,1)
links.new(lightpath.outputs['Is Camera Ray'], background.inputs['Strength'])
worldout = nodes.new('ShaderNodeOutputWorld')
links.new(background.outputs['Background'], worldout.inputs['Surface'])
scene.world = world

layer = scene.view_layers[0]
layer.use_pass_diffuse_direct = layer.use_pass_diffuse_indirect = layer.use_pass_diffuse_color = True
layer.use_pass_glossy_direct = layer.use_pass_glossy_indirect = layer.use_pass_glossy_color = True
scene.render.image_settings.file_format = 'OPEN_EXR'
scene.render.image_settings.color_depth = '32'
scene.render.image_settings.exr_codec = 'ZIP'

bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'sss_comparison.blend'))
