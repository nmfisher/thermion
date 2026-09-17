"""Offline viewer of actual Thermion and Cycles renders, with independent profile plots."""
from pathlib import Path
from PIL import Image
import argparse,base64,json,statistics,sys
ROOT=Path(__file__).resolve().parent
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--thermion-output',type=Path,default=ROOT/'samples/thermion')
parser.add_argument('--cycles-output',type=Path,default=ROOT/'samples/cycles')
args=parser.parse_args()
T=args.thermion_output
C=args.cycles_output
sys.path.insert(0,str(ROOT.parent))
from sss_reference import marginal_cdf
audit=json.loads((T/'sss_replacement/audit.json').read_text())
images={};pairs=[]
def add(key,label,path):
 images[key]=dict(label=label,url='data:image/png;base64,'+base64.b64encode(path.read_bytes()).decode())
for name,bs,d in [('off','sphere_off',0),('default','sphere_d0.6mm',.6),('wide','sphere_d1.2mm',1.2)]:
 add('t'+name,f'Thermion · '+('SSS off' if not d else f'Burley dR = {d} mm'),T/'sss_demo_replacement'/f'sphere_{name}_view0.png')
 add('b'+name,f'Cycles · '+('SSS off' if not d else f'Burley dR = {d} mm'),C/f'{bs}.png')
 pairs.append([f'Ball · '+('both off' if not d else f'matched dR = {d} mm'),'t'+name,'b'+name])
 if d:
  pairs.extend([[f'Thermion ball · off / dR = {d} mm','toff','t'+name],[f'Cycles ball · off / dR = {d} mm','boff','b'+name]])
  add('old'+name,f'Previous Gaussian · sigmaR = {d} mm',ROOT/'samples/previous-gaussian'/f'{name}.png')
  pairs.append([f'Ball · previous Gaussian / new Burley ({d} mm, different profiles)','old'+name,'t'+name])
edge=[]
for prefix in ['t','b','old']:
 for name in ['off','default','wide']:
  if prefix=='old' and name=='off':continue
  k=prefix+name
  im=Image.open(__import__('io').BytesIO(base64.b64decode(images[k]['url'].split(',')[1]))).convert('RGB')
  values={x:statistics.mean(im.getpixel((x,y))[0] for y in range(316,325)) for x in range(308,337)}
  lo=statistics.mean(values[x] for x in range(310,315));hi=statistics.mean(values[x] for x in range(327,333))
  v={x:(z-lo)/(hi-lo) for x,z in values.items()}
  def cross(t):return next(x+(t-v[x])/(v[x+1]-v[x]) for x in range(314,329) if v[x]<=t<v[x+1])
  edge.append(dict(label=images[k]['label'],width=cross(.9)-cross(.1)))
profiles=[]
for ortho in ['false','true']:
 for kind in ['texture','shadow']:
  for d in ['off','6.25','12.5']:
   suffix='off' if d=='off' else 'd'+d+'mm'
   key=kind+'_'+ortho+'_'+d
   add('t'+key,f'Thermion · {kind} · '+('orthographic' if ortho=='true' else 'perspective')+' · '+d,T/'sss_replacement'/f'{kind}_{ortho}_4.0_{d}_view0.png')
   add('b'+key,f'Cycles · {kind} · '+('orthographic' if ortho=='true' else 'perspective')+' · '+d,C/f'{kind}_{ortho}_{suffix}_linear.png')
   pairs.append([f'{kind.title()} edge · '+('orthographic' if ortho=='true' else 'perspective')+' · '+('off' if d=='off' else f'd = {d} mm'),'t'+key,'b'+key])
   if kind=='shadow' and d!='off':
    a=audit[f'shadow_{ortho}_4.0_{d}'];off=audit[f'shadow_{ortho}_4.0_off_row']
    b=json.loads((C/f'shadow_{ortho}_{suffix}.json').read_text())['center_row']
    bo=json.loads((C/f'shadow_{ortho}_off.json').read_text())['center_row']
    tnorm=statistics.mean(off[96:112]);bnorm=statistics.mean(r[0] for r in bo[96:112])
    tr=[v/tnorm for v in a['row']];br=[r[0]/bnorm for r in b]
    expected=[marginal_cdf(x-63.5,float(d)/6.25) for x in range(128)]
    profiles.append(dict(label=('Orthographic' if ortho=='true' else 'Perspective')+f', d={d} mm',thermion=tr,cycles=br,analytic=expected,
      max_cross_renderer_error=max(abs(tr[x]-br[x]) for x in range(40,88))))
metrics=dict(texture_edges=edge,shadow_profiles=profiles,notes='Shadow curves normalized by each renderer off bright plateau, columns 96–111. Analytic curve is point-receiver flat-plane Burley CDF. Cycles averages receivers across the output pixel; Thermion gathers a pixel-integrated input at its center. PCF and finite sampling also differ. No fitted radius or translation.')
(ROOT/'burley-metrics.json').write_text(json.dumps(metrics,indent=2))
rows=''.join(f'<tr><td>{m["label"]}</td><td>{m["width"]:.2f} px</td></tr>' for m in edge)
html='''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Thermion / Cycles · Burley diffusion</title><style>body{max-width:1320px;margin:28px auto;padding:0 24px;background:#131922;color:#e6edf6;font:16px system-ui;line-height:1.6}p{max-width:1000px}a{color:#9bcdff}select,button{font:inherit;padding:9px;background:#273448;color:inherit;border:1px solid #596b82;border-radius:5px}#pair{display:grid;grid-template-columns:1fr 1fr;gap:20px}#pair.native{grid-template-columns:640px 640px}#scroll{overflow:auto}figure{margin:0}img{width:100%;display:block}figcaption{padding:10px 0}#controls{display:flex;gap:15px;flex-wrap:wrap;margin:20px 0}td,th{padding:4px 24px 4px 0;text-align:left}svg{width:100%;max-width:850px}code{color:#ffd299}.notice{border-left:3px solid #8cc7ff;padding:12px 18px;background:#1d2938}@media(max-width:700px){#pair{grid-template-columns:1fr}}</style>
<h1>Diffuse lighting spreads; the painted grid stays sharp</h1>
<p>The redesigned Thermion pass applies a normalized Burley profile to uncolored diffuse lighting, then applies the receiving pixel’s albedo. These are actual renderer outputs, with no sharpening or denoising.</p>
<p class="notice">The ball uses the same 100 mm radius, mesh, UV grid, camera and directional light. Red/green/blue diffusion distances are in the ratio 1 : 0.5 : 0.25. We now compare <strong>Burley against Burley</strong>. The old Gaussian and Cycles Random Walk parameters were not equivalent. Matching this radial profile does not make a screen-space gather equivalent to Cycles’ surface transport on curved or hidden geometry.</p>
<div id="controls"><select id="which" aria-label="Render comparison"></select><button id="swap">Swap sides</button><label><input type="checkbox" id="native"> Native ball pixels</label></div><div id="scroll"><div id="pair"><figure><img id="left"><figcaption id="leftlabel"></figcaption></figure><figure><img id="right"><figcaption id="rightlabel"></figcaption></figure></div></div>
<p>Ball PNGs share Filament’s ACES display transform. The flat diagnostic images display linear RGB directly in both engines, with post-processing disabled in Thermion. Do not compare their brightness to the ball. Cycles 4.5.0 uses 2,048 samples for the ball and 4,096 for the fixtures, with no denoising.</p>
<h2>Texture-edge sharpness on the ball</h2><table><tr><th>Render</th><th>10–90% width</th></tr>ROWS</table><p>This single display-space edge averages red over rows 316–324, with plateaus at columns 310–314 and 327–332. It includes texture filtering and display conversion; it is not a physical radius estimate. The independent uniformly lit black/colored slab is unchanged in Thermion across all eight tested distance/projection/radius cases.</p>
<h2>Shadow spread on a uniform slab</h2><select id="curve" aria-label="Shadow profile"></select><svg id="plot" viewBox="0 0 850 320" role="img" aria-label="Normalized shadow transition"></svg><p style="color:#f3bc6a">Orange: Thermion · <span style="color:#82c5ff">Blue: Cycles</span> · <span style="color:#e4e8ed">White dashed: analytic Burley profile</span></p><p id="error"></p><p>Curves use each engine’s unscattered bright plateau, without fitting distance or translating the edge. Cycles samples the output pixel area; the analytic curve evaluates its center. Thermion additionally inherits its original PCF shadow transition. The GPU’s separate regression convolves that measured off-state edge with an independent angular integral and has at most 1.1% normalized error.</p>
<p class="notice"><strong>Validation status: 18/19 GPU tests pass.</strong> A strict indirect-specular regression still changes five pixels with SSS enabled and geometric specular antialiasing active, even without selected materials. Its cause is unresolved; the test has not been relaxed. This implementation is not ready to merge.</p><h2>What the millimeters mean</h2><p><code>R(r,d) = [exp(−r/d) + exp(−r/(3d))] / (8πdr)</code>. The distance d is the exponential profile length, not Gaussian sigma or an unqualified Blender radius. Both profiles truncate at 16d and normalize the retained mass. Cycles 4.5’s live <code>bssrdf_setup_radius</code> multiplies Burley node radius × scale by 1/(4π); this reference therefore sets that product to <strong>4πd</strong>. This conversion comes from source, not visual fitting. The unused older albedo-dependent setup helper is not the live conversion.</p>
<p>Thermion is still an expensive screen-space reference approximation: the gather is capped at 32 pixels per axis, returns rejected/missing mass to the center and approximates distance in the local image plane. It cannot recover hidden/offscreen transport or thin-object transmission. The defaults are synthetic, not calibrated skin.</p>
<p><a href="README.md#reproduction">Recreate the packed Blender scenes</a> · <a href="render_model_reference.py">Cycles reproduction</a> · <a href="burley-metrics.json">Measurements</a> · <a href="../../../docs/sss-audit-and-redesign.md">Historical failed-texture audit</a> · <a href="https://github.com/blender/blender/blob/v4.5.0/intern/cycles/kernel/closure/bssrdf.h">Cycles profile source</a></p>
<script>const images=IMAGES,pairs=PAIRS,profiles=PROFILES;const sel=document.getElementById('which');pairs.forEach((p,i)=>sel.add(new Option(p[0],i)));let swap=false;function refresh(){let k=pairs[sel.value].slice(1);if(swap)k.reverse();['left','right'].forEach((side,i)=>{const d=images[k[i]];document.getElementById(side).src=d.url;document.getElementById(side).alt=d.label;document.getElementById(side+'label').textContent=d.label})}sel.onchange=refresh;document.getElementById('swap').onclick=()=>{swap=!swap;refresh()};document.getElementById('native').onchange=e=>document.getElementById('pair').classList.toggle('native',e.target.checked);sel.value=1;refresh();const curve=document.getElementById('curve');profiles.forEach((p,i)=>curve.add(new Option(p.label,i)));function plot(){const p=profiles[curve.value];let s='';for(let y=0;y<=1;y+=.25){s+=`<path d="M50 ${280-y*240} H820" stroke="#39485b"/><text x="10" y="${285-y*240}" fill="#d2dbe7">${y}</text>`}for(const [k,c,dash]of[['analytic','#e4e8ed','5 4'],['cycles','#82c5ff',''],['thermion','#f3bc6a','']]){const xy=p[k].slice(48,80).map((v,i)=>`${50+i*24.8},${280-v*240}`).join(' ');s+=`<polyline points="${xy}" fill="none" stroke="${c}" stroke-width="2" stroke-dasharray="${dash}"/>`}document.getElementById('plot').innerHTML=s;document.getElementById('error').textContent=`Maximum Thermion/Cycles difference over columns 40–87: ${(p.max_cross_renderer_error*100).toFixed(2)}% of the off-state light-to-shadow contrast.`}curve.onchange=plot;plot();</script></html>'''
(ROOT/'comparison-burley.html').write_text(html.replace('ROWS',rows).replace('IMAGES',json.dumps(images)).replace('PAIRS',json.dumps(pairs)).replace('PROFILES',json.dumps(profiles)))
print(json.dumps(dict(texture_edges=edge,shadow_errors=[(p['label'],p['max_cross_renderer_error']) for p in profiles]),indent=2))
