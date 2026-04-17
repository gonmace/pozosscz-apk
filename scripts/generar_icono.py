"""
Genera assets/images/icon.png (1024x1024).
Ejecutar desde la raíz del proyecto:
    python scripts/generar_icono.py
"""
import pathlib, math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024

# ── Colores ─────────────────────────────────────────────────────────────────
BG_TOP    = np.array([26,  29,  46], dtype=np.float32)   # #1A1D2E
BG_BOT    = np.array([13,  16,  23], dtype=np.float32)   # #0D1017
DROP_TOP  = np.array([52, 211, 118], dtype=np.float32)   # verde claro
DROP_BOT  = np.array([22,  90,  50], dtype=np.float32)   # verde oscuro


def degradado_vertical(size, c_top, c_bot):
    """Imagen PIL con degradado vertical top→bottom."""
    t = np.linspace(0, 1, size, dtype=np.float32)[:, None]   # (size, 1)
    rgb = (c_top * (1 - t) + c_bot * t).astype(np.uint8)     # (size, 3)
    arr = np.repeat(rgb[:, np.newaxis, :], size, axis=1)      # (size, size, 3)
    return Image.fromarray(arr, mode="RGB").convert("RGBA")


def bezier_cubica(p0, p1, p2, p3, pasos=100):
    pts = []
    for i in range(pasos + 1):
        t  = i / pasos
        mt = 1 - t
        x  = mt**3*p0[0] + 3*mt**2*t*p1[0] + 3*mt*t**2*p2[0] + t**3*p3[0]
        y  = mt**3*p0[1] + 3*mt**2*t*p1[1] + 3*mt*t**2*p2[1] + t**3*p3[1]
        pts.append((x, y))
    return pts


def forma_gota(cx, cy_base, radio, alto):
    """
    Polígono con forma de gota.
    punta arriba (cy_base - alto), base circular centrada en (cx, cy_base).
    """
    r  = radio
    py = cy_base - alto          # y de la punta

    # Derecha: punta → mitad derecha de la base
    ctrl_d1 = (cx + r * 0.18, py + alto * 0.10)
    ctrl_d2 = (cx + r * 1.05, cy_base - alto * 0.55)
    mid_d   = (cx + r,        cy_base - alto * 0.18)

    # Izquierda: mitad izquierda de la base → punta
    mid_i   = (cx - r,        cy_base - alto * 0.18)
    ctrl_i1 = (cx - r * 1.05, cy_base - alto * 0.55)
    ctrl_i2 = (cx - r * 0.18, py + alto * 0.10)

    pts  = bezier_cubica((cx, py), ctrl_d1, ctrl_d2, mid_d)
    # Arco inferior (semi-círculo) de derecha a izquierda
    for ang in range(0, 181, 3):
        rad = math.radians(ang)
        pts.append((cx + r * math.cos(rad), cy_base + r * math.sin(rad)))
    pts += bezier_cubica(mid_i, ctrl_i1, ctrl_i2, (cx, py))
    return [(int(x), int(y)) for x, y in pts]


def mask_esquinas(size, radio):
    m = Image.new("L", (size, size), 0)
    ImageDraw.Draw(m).rounded_rectangle([(0,0),(size-1,size-1)], radius=radio, fill=255)
    return m


# ── 1. Fondo ────────────────────────────────────────────────────────────────
fondo = degradado_vertical(SIZE, BG_TOP, BG_BOT)
fondo.putalpha(mask_esquinas(SIZE, int(SIZE * 0.21)))

# ── 2. Forma de la gota ─────────────────────────────────────────────────────
cx      = SIZE // 2
cy_base = int(SIZE * 0.635)
radio   = int(SIZE * 0.215)
alto    = int(SIZE * 0.505)

puntos = forma_gota(cx, cy_base, radio, alto)

# Máscara de la gota
mask_gota = Image.new("L", (SIZE, SIZE), 0)
ImageDraw.Draw(mask_gota).polygon(puntos, fill=255)

# Degradado vertical verde enmascarado a la gota
grad_verde = degradado_vertical(SIZE, DROP_TOP, DROP_BOT)
grad_verde.putalpha(mask_gota)

# ── 3. Brillo (reflejo superior-izquierdo) ──────────────────────────────────
brillo = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
bx = int(cx - radio * 0.28)
by = int(cy_base - alto + int(alto * 0.17))
br = int(radio * 0.38)
ImageDraw.Draw(brillo).ellipse([(bx-br, by-br), (bx+br, by+br)],
                                fill=(255, 255, 255, 120))
brillo = brillo.filter(ImageFilter.GaussianBlur(radius=int(br * 0.65)))
# recortar a la forma de la gota
arr_b = np.array(brillo)
arr_m = np.array(mask_gota)
arr_b[:, :, 3] = (arr_b[:, :, 3].astype(np.uint16) * arr_m // 255).astype(np.uint8)
brillo = Image.fromarray(arr_b, mode="RGBA")

# ── 4. Ondas de agua (dentro de la gota) ────────────────────────────────────
ondas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
d_o = ImageDraw.Draw(ondas)
grosor = max(7, int(SIZE * 0.013))
color_onda = (255, 255, 255, 75)
pasos = 90

for y_base, amp_frac in [(cy_base + int(radio * 0.1), 0.16),
                          (cy_base + int(radio * 0.52), 0.12)]:
    ancho = int(radio * 1.05)
    amp   = int(radio * amp_frac)
    prev  = None
    for i in range(pasos + 1):
        t  = i / pasos
        x  = cx - ancho + t * ancho * 2
        y  = y_base + amp * math.sin(t * 2 * math.pi)
        pt = (int(x), int(y))
        if prev:
            d_o.line([prev, pt], fill=color_onda, width=grosor)
        prev = pt

arr_o = np.array(ondas)
arr_o[:, :, 3] = (arr_o[:, :, 3].astype(np.uint16) * arr_m // 255).astype(np.uint8)
ondas = Image.fromarray(arr_o, mode="RGBA")

# ── 5. Sombra suave bajo la gota ────────────────────────────────────────────
sombra = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
d_s = ImageDraw.Draw(sombra)
for i in range(4):
    pts_s = forma_gota(cx, cy_base + 10 + i * 6, radio, alto)
    d_s.polygon(pts_s, fill=(0, 0, 0, 25 - i * 5))
sombra = sombra.filter(ImageFilter.GaussianBlur(radius=22))

# ── 6. Composición final ────────────────────────────────────────────────────
out_img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
out_img = Image.alpha_composite(out_img, fondo)
out_img = Image.alpha_composite(out_img, sombra)
out_img = Image.alpha_composite(out_img, grad_verde)
out_img = Image.alpha_composite(out_img, brillo)
out_img = Image.alpha_composite(out_img, ondas)

out = pathlib.Path("assets/images/icon.png")
out_img.save(str(out), "PNG")
print(f"Icono generado: {out} ({SIZE}x{SIZE})")
