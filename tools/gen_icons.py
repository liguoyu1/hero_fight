#!/usr/bin/env python3
"""
Hero Fighter App Icon — CONCRETE DESIGN
Central element: detailed clenched fist (universal fighting symbol)
Framing: gold ring + red/blue energy arcs
Background: dark gradient
"""
from PIL import Image, ImageDraw
import os, math

base_dir = '/Users/guoyuli/Documents/code_s/hero_fighter/ios/Runner/Assets.xcassets/AppIcon.appiconset'

def hex_rgba(h, a=255):
    return (int(h[0:2],16), int(h[2:4],16), int(h[4:6],16), a)

# Palette
BG1  = hex_rgba('0D082B')
BG2  = hex_rgba('1A1040')
GOLD    = hex_rgba('FFD700')
GOLD2   = hex_rgba('E6B800')
GOLD3   = hex_rgba('B8960F')
RED     = hex_rgba('FF3333')
RED2    = hex_rgba('CC1111')
BLUE    = hex_rgba('3366FF')
WHITE   = hex_rgba('FFFFFF')
SKIN    = hex_rgba('C4956A')      # skin tone
SKIN_D  = hex_rgba('8B5E3C')      # dark skin
SKIN_L  = hex_rgba('D4A574')      # light skin
GLOVE   = hex_rgba('8B0000')      # dark red glove
GLOVE_L = hex_rgba('CC2222')      # lighter glove
BLACK   = hex_rgba('000000')

def draw_fist(draw, cx, cy, s):
    """
    Draw a detailed clenched fist — palm facing viewer, fingers curled.
    This is the most universally recognized fighting symbol.
    Scale: s is relative size unit (1/100 of diameter)
    """
    # ── Wrist / forearm ──
    wrist_top = cy + s * 25
    wrist_bot = cy + s * 42
    wrist_l = cx - s * 11
    wrist_r = cx + s * 11
    
    # Forearm (angled slightly)
    draw.polygon([
        (wrist_l - s*2, wrist_top), (wrist_r + s*2, wrist_top),
        (wrist_r + s*1, wrist_bot), (wrist_l - s*1, wrist_bot),
    ], fill=GLOVE)
    
    # Wrist wrap / band
    draw.rounded_rectangle(
        [wrist_l - s*4, wrist_top + s*5, wrist_r + s*4, wrist_top + s*10],
        radius=s*1, fill=GOLD)
    
    # ── Main fist body (palm area) ──
    fist_t = cy - s * 18   # top of fist
    fist_b = cy + s * 22   # bottom (above wrist)
    fist_l = cx - s * 22
    fist_r = cx + s * 22
    
    # Main fist shape — rounded rectangle
    draw.rounded_rectangle(
        [fist_l, fist_t, fist_r, fist_b],
        radius=s*8, fill=GLOVE)
    
    # Fist highlight (light from upper-left)
    draw.rounded_rectangle(
        [fist_l + s*3, fist_t + s*3, fist_r - s*8, fist_b - s*10],
        radius=s*6, fill=GLOVE_L)
    
    # ── Knuckles (4 fingers curled, visible on top) ──
    knuckle_y = fist_t + s * 3
    knuckle_h = s * 12
    knuckle_w = s * 7
    knuckle_gap = s * 1
    knuckle_start_x = cx - s * 14
    
    knuckle_colors = [SKIN_L, SKIN, SKIN_L, SKIN]
    for i in range(4):
        kx = knuckle_start_x + i * (knuckle_w + knuckle_gap)
        # Finger segment (curled)
        draw.rounded_rectangle(
            [kx, knuckle_y, kx + knuckle_w, knuckle_y + knuckle_h],
            radius=s*2, fill=knuckle_colors[i])
        # Knuckle highlight
        draw.rounded_rectangle(
            [kx + s*1, knuckle_y + s*1, kx + knuckle_w - s*1, knuckle_y + s*4],
            radius=s*1, fill=SKIN_L)
        # Knuckle crease
        draw.line([(kx + knuckle_w//2, knuckle_y + s*4), (kx + knuckle_w//2, knuckle_y + s*8)],
                  fill=SKIN_D, width=max(1,int(s*0.8)))
    
    # ── Thumb (curled over fingers on the side) ──
    thumb_x = fist_r - s * 2
    thumb_y = fist_t + s * 6
    thumb_w = s * 7
    thumb_h = s * 10
    draw.rounded_rectangle(
        [thumb_x, thumb_y, thumb_x + thumb_w, thumb_y + thumb_h],
        radius=s*3, fill=SKIN)
    # Thumb nail
    draw.ellipse([thumb_x + s*1, thumb_y + s*1, thumb_x + thumb_w - s*1, thumb_y + s*5],
                 fill=SKIN_L)
    
    # ── Finger curl lines (creases showing fingers are clenched) ──
    for i in range(3):
        line_y = fist_t + s * 14 + i * s * 2
        draw.arc([fist_l + s*5, line_y - s*2, fist_r - s*8, line_y + s*2],
                 0, 180, fill=hex_rgba('000000', 60), width=max(1,int(s*0.6)))
    
    # ── Impact energy lines radiating from fist ──
    center_x, center_y = cx, cy - s * 3
    for angle in [30, 60, 120, 150, 210, 240, 300, 330]:
        rad = math.radians(angle)
        length = s * 32
        ex = center_x + math.cos(rad) * length
        ey = center_y + math.sin(rad) * length
        # Gradient-like: draw 3 segments with decreasing alpha
        for seg in range(3):
            t0 = seg / 3
            t1 = (seg + 1) / 3
            sx = center_x + math.cos(rad) * length * t0
            sy = center_y + math.sin(rad) * length * t0
            ex_seg = center_x + math.cos(rad) * length * t1
            ey_seg = center_y + math.sin(rad) * length * t1
            alpha = int(255 * (1 - t0) * 0.6)
            draw.line([(sx, sy), (ex_seg, ey_seg)], 
                      fill=hex_rgba('FFD700', alpha), width=max(1,int(s*1.5)))

def create_icon(size, path):
    img = Image.new('RGBA', (size, size), (0,0,0,0))
    draw = ImageDraw.Draw(img)
    cx, cy = size/2, size/2
    s = size / 140.0  # scale unit (1% of 140px reference)
    
    # ── Background: radial gradient ──
    max_r = size / 2 - size * 0.03
    for r in range(int(max_r), 0, -2):
        t = r / max_r
        rr = int(13 * (1-t) + 30 * t)
        gg = int(8 * (1-t) + 20 * t)
        bb = int(43 * (1-t) + 70 * t)
        aa = int(255 * (1 - t*0.3))
        draw.ellipse([cx-r, cy-r, cx+r, cy+r], fill=(rr,gg,bb,aa))
    
    # ── Outer gold ring (bold, visible at all sizes) ──
    ring_r = size/2 - size*0.025
    ring_w = max(3, int(size * 0.035))
    draw.ellipse([cx-ring_r, cy-ring_r, cx+ring_r, cy+ring_r],
                 outline=GOLD, width=ring_w)
    # Ring inner shadow
    draw.ellipse([cx-ring_r+ring_w, cy-ring_r+ring_w, cx+ring_r-ring_w, cy+ring_r-ring_w],
                 outline=GOLD3, width=max(1,int(ring_w*0.4)))
    
    # ── Left energy arc (blue, P1) ──
    arc_r = ring_r - ring_w * 2
    arc_w = max(2, int(s * 4))
    draw.arc([cx-arc_r, cy-arc_r, cx+arc_r, cy+arc_r],
             210, 300, fill=BLUE, width=arc_w)
    
    # ── Right energy arc (red, P2) ──
    draw.arc([cx-arc_r, cy-arc_r, cx+arc_r, cy+arc_r],
             60, 150, fill=RED, width=arc_w)
    
    # ── Glow behind fist ──
    glow_r = s * 22
    for i in range(int(glow_r), 0, -2):
        t = i / glow_r
        draw.ellipse([cx-i, cy-s*5-i, cx+i, cy-s*5+i], 
                     fill=hex_rgba('FFD700', int(80*(1-t)**2)))
    
    # ── FIST (central element) ──
    draw_fist(draw, cx, cy + s*2, s)
    
    # ── Small "HF" text at bottom (branding) ──
    # Only on sizes >= 60px where text would be legible
    if size >= 60:
        # Use simple shapes to suggest "HF" — too small for actual text rendering
        pass
    
    # ── Corner accents ──
    corner_r = s * 6
    for (cx_c, cy_c) in [(cx-ring_r*0.8, cy-ring_r*0.8), (cx+ring_r*0.8, cy-ring_r*0.8),
                          (cx-ring_r*0.8, cy+ring_r*0.8), (cx+ring_r*0.8, cy+ring_r*0.8)]:
        draw.ellipse([cx_c-corner_r, cy_c-corner_r, cx_c+corner_r, cy_c+corner_r],
                     fill=GOLD)
    
    img.save(path, 'PNG')

sizes = {
    'Icon-App-20x20@1x.png': 20, 'Icon-App-20x20@2x.png': 40, 'Icon-App-20x20@3x.png': 60,
    'Icon-App-29x29@1x.png': 29, 'Icon-App-29x29@2x.png': 58, 'Icon-App-29x29@3x.png': 87,
    'Icon-App-40x40@1x.png': 40, 'Icon-App-40x40@2x.png': 80, 'Icon-App-40x40@3x.png': 120,
    'Icon-App-60x60@2x.png': 120, 'Icon-App-60x60@3x.png': 180,
    'Icon-App-76x76@1x.png': 76, 'Icon-App-76x76@2x.png': 152,
    'Icon-App-83.5x83.5@2x.png': 167,
    'Icon-App-1024x1024@1x.png': 1024,
}

for name, size in sizes.items():
    path = os.path.join(base_dir, name)
    create_icon(size, path)
    print(f'  ✓ {name}')

print(f'\n✅ 15 icons: clenched fist + gold ring + energy arcs')
print('Format: 32-bit RGBA truecolor')
