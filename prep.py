# Turns the Still-Waters art into SUBMERGE-style wallpaper assets.
# Only the straight pose (frame 3) is kept; the wallpaper bends it in a shader for smooth swimming.
import numpy as np, math, os, sys, shutil
from PIL import Image, ImageFilter
SRC = sys.argv[1]; OUT = sys.argv[2]
shutil.rmtree(OUT, ignore_errors=True)
for d in ('fish', 'water', 'fx'): os.makedirs(f'{OUT}/{d}')

def css_filter(rgb, hue, sat):
    # CSS saturate() then hue-rotate(), same matrices browsers use
    s = sat / 100
    S = np.array([[.213+.787*s, .715-.715*s, .072-.072*s],
                  [.213-.213*s, .715+.285*s, .072-.072*s],
                  [.213-.213*s, .715-.715*s, .072+.928*s]])
    c, n = math.cos(math.radians(hue)), math.sin(math.radians(hue))
    H = np.array([[.213+c*.787-n*.213, .715-c*.715-n*.715, .072-c*.072+n*.928],
                  [.213-c*.213+n*.143, .715+c*.285+n*.140, .072-c*.072-n*.283],
                  [.213-c*.213-n*.787, .715-c*.715+n*.715, .072+c*.928+n*.072]])
    return np.clip(rgb @ (H @ S).T, 0, 255)

def gradient_map(lum, stops):
    xs = [s[0] for s in stops]
    return np.stack([np.interp(lum, xs, [s[1][i] for s in stops]) for i in range(3)], -1)

def blobs(shape, seed, scale=40):
    # soft random patches for kohaku-style white markings
    rng = np.random.default_rng(seed)
    small = rng.random((shape[0]//scale+2, shape[1]//scale+2))
    m = np.array(Image.fromarray((small*255).astype(np.uint8)).resize(shape[::-1], Image.BICUBIC)).astype(float)/255
    return np.clip((m-0.5)*5+0.5, 0, 1)

GOLD = [(0,(60,6,0)), (0.45,(200,45,0)), (0.75,(255,110,10)), (1,(255,200,120))]
# pale palettes from the artist's site, then goldfish ones
PALE = [(0,110),(0,150),(150,190),(185,200),(140,200),(300,180),(220,160)]
for t in range(1,7):
    im = np.array(Image.open(f'{SRC}/Fish{t}/Fish{t}-3.png').convert('RGBA')).astype(float)
    lum = im[...,:3].mean(2)/255
    lumn = (lum - lum[im[...,3]>40].min()) / (np.ptp(lum[im[...,3]>40]) + 1e-6)
    variants = []
    for h,s in PALE:
        o = im.copy(); o[...,:3] = css_filter(im[...,:3], h, s); variants.append(o)
    for k in range(3):
        o = im.copy(); gold = gradient_map(np.clip(lumn*1.1, 0, 1), GOLD)
        if k == 1:   # kohaku: orange with white patches
            m = blobs(lum.shape, t*7+k)[...,None]; gold = gold*(1-m) + im[...,:3]*m
        if k == 2:   # deeper red-orange
            gold = gold * np.array([1.0, 0.75, 0.6])
        o[...,:3] = gold; variants.append(o)
    for p,o in enumerate(variants):
        Image.fromarray(np.clip(o,0,255).astype(np.uint8)).save(f'{OUT}/fish/f{t}_{p}.png', optimize=True)
    sh = f'{SRC}/Fish{t}/Fish{t}Shadow-3.png'
    if os.path.exists(sh):
        a = np.array(Image.open(sh).convert('RGBA')); a[...,:3] = (0,2,10)
        Image.fromarray(a).save(f'{OUT}/fish/s{t}.png', optimize=True)
print('palettes', len(variants))

# water: electric cobalt with crushed blacks
for i in range(1,6):
    w = np.array(Image.open(f'{SRC}/Water/Water-{i}.webp').convert('RGB')).astype(float)/255
    lum = w.mean(2)
    hgt, wid = lum.shape
    yy, xx = np.mgrid[0:hgt,0:wid]
    l = np.clip((lum-0.25)/0.45, 0, 1) ** 1.8 * (0.55 + 0.45*(1-yy/hgt))   # brighter toward the surface
    out = gradient_map(l, [(0,(1,3,12)),(0.35,(4,20,70)),(0.7,(14,60,190)),(1,(70,150,255))])
    Image.fromarray(np.clip(out,0,255).astype(np.uint8)).save(f'{OUT}/water/w{i}.jpg', quality=93)
for i in range(1,8):
    c = np.array(Image.open(f'{SRC}/Caustics/Caustics-{i}.webp').convert('RGBA')).astype(float)
    c[...,:3] = c[...,:3].mean(2,keepdims=True)*np.array([0.75,1.15,1.6]) + np.array([10,30,60])
    c[...,3] *= 1.15
    Image.fromarray(np.clip(c,0,255).astype(np.uint8)).save(f'{OUT}/water/c{i}.png', optimize=True)

def radial(name, size, rgb, falloff=2.0, peak=1.0):
    yy, xx = np.mgrid[0:size,0:size]
    d = np.sqrt(((xx-size/2)/(size/2))**2 + ((yy-size/2)/(size/2))**2)
    a = np.clip(1-d,0,1)**falloff*peak
    img = np.zeros((size,size,4)); img[...,:3] = rgb; img[...,3] = a*255
    Image.fromarray(img.astype(np.uint8)).save(f'{OUT}/fx/{name}.png', optimize=True)
radial('mote', 64, (200,225,255), 2.2)

# air bubble: thin bright rim, clear middle, a highlight up top
yy, xx = np.mgrid[0:64,0:64]
d = np.sqrt((xx-32)**2 + (yy-32)**2) / 30
rim = np.clip(1 - np.abs(d - 0.88) / 0.12, 0, 1) ** 1.5
hl = np.clip(1 - np.sqrt((xx-22)**2 + (yy-20)**2) / 7, 0, 1) ** 2
fill = np.clip(1 - d, 0, 1) * 0.12
a = np.clip(rim * 0.85 + hl + fill, 0, 1) * (d < 1)
b = np.zeros((64,64,4)); b[...,:3] = (215,235,255); b[...,3] = a*255
Image.fromarray(b.astype(np.uint8)).save(f'{OUT}/fx/bubble.png', optimize=True)
radial('glow', 256, (150,190,255), 2.0)
radial('light_blue', 512, (40,110,255), 1.7, 0.6)
radial('light_cyan', 512, (90,220,255), 1.8, 0.5)
radial('light_violet', 512, (130,80,255), 1.8, 0.45)
radial('light_warm', 512, (255,140,60), 1.9, 0.35)
radial('light_surface', 512, (190,225,255), 1.5, 0.6)
print('done')
