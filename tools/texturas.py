#!/usr/bin/env python3
"""Texturas de los temas de la mazmorra a partir de las imágenes de Pixmith (ChatGPT).

    python3 tools/texturas.py <color.png|jpg> <carpeta_salida> <nombre> [opciones]

Deja en la carpeta (WebP, 1024 px por defecto):
    <nombre>_color.webp      el color, sin costuras al repetirse
    <nombre>_normal.webp     relieve (mapa de normales de Godot, Y hacia arriba)
    <nombre>_rugosidad.webp  rugosidad (blanco = mate)
    <nombre>_brillo.webp     (con --brillo) lo que brilla: grietas de lava, vetas…

Opciones:
    --alturas=<png>   mapa de alturas en gris de Pixmith (blanco = sale). Si no cuadra con el color
                      (Pixmith ha movido las piedras), se avisa y se saca del color, como sin él.
    --brillo          saca la máscara de lo que brilla (naranjas y amarillos muy saturados)
    --todo-brilla     la imagen entera brilla (lava): la máscara es la luz de cada píxel
    --fuerza=N        relieve más o menos marcado (por defecto 6)
    --px=N            tamaño de salida (por defecto 1024)
    --sin-arreglo     no tocar los bordes aunque no casen al repetir
    --mosaico[=ruta]  guarda la textura repetida 3×3 (por defecto /tmp/<nombre>_mosaico.jpg) para ver costuras,
                      patrones que se repiten y si la escala es buena; dice la costura que queda tras el arreglo
"""
import sys
import numpy as np
from PIL import Image, ImageFilter

def _gris(a):
    return a[..., 0] * .299 + a[..., 1] * .587 + a[..., 2] * .114

def costura(a):
    """cuánto cambia al pasar del borde derecho al izquierdo (y de abajo a arriba), frente al cambio normal"""
    g = _gris(a)
    borde = (np.abs(g[:, 0] - g[:, -1]).mean() + np.abs(g[0, :] - g[-1, :]).mean()) / 2
    dentro = (np.abs(np.diff(g, axis=1)).mean() + np.abs(np.diff(g, axis=0)).mean()) / 2
    return borde / max(dentro, 1e-6)

def sin_costura(a, banda=.12):
    """mezcla los bordes con la imagen desplazada media vuelta (que sí casa al repetirse)"""
    h, w = a.shape[:2]
    rodada = np.roll(np.roll(a, h // 2, axis=0), w // 2, axis=1)
    def peso(n):
        u = np.minimum(np.arange(n), np.arange(n)[::-1]) / (n * banda)
        u = np.clip(u, 0, 1)
        return u * u * (3 - 2 * u)
    m = np.outer(peso(h), peso(w))
    if a.ndim == 3:
        m = m[..., None]
    return a * m + rodada * (1 - m)

def mascara_brillo(a):
    """naranjas, rojos y amarillos encendidos: mucho rojo, poco azul y bastante luz"""
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    calor = np.clip((r - b) * 1.6 - .25, 0, 1)
    luz = np.clip((np.maximum(r, g) - .35) * 2.2, 0, 1)
    return np.clip(calor * luz * 1.4, 0, 1)

def alturas_del_color(a, brillo):
    """lo claro sale y lo oscuro se hunde; lo que brilla son grietas (abajo del todo)"""
    g = _gris(a)
    g = np.array(Image.fromarray((g * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.2)), dtype=np.float32) / 255
    g = (g - g.min()) / max(g.max() - g.min(), 1e-6)
    if brillo is not None:
        g = g * (1 - brillo)
    return g

def normales(alt, fuerza):
    """Sobel con vuelta (la textura se repite) → normal de Godot (OpenGL: Y arriba)"""
    def d(eje):
        return (np.roll(alt, -1, eje) - np.roll(alt, 1, eje)) * .5
    dx = d(1) * 2 + (np.roll(d(1), 1, 0) + np.roll(d(1), -1, 0)) * .5
    dy = d(0) * 2 + (np.roll(d(0), 1, 1) + np.roll(d(0), -1, 1)) * .5
    nx, ny, nz = -dx * fuerza, dy * fuerza, np.ones_like(alt)
    l = np.sqrt(nx * nx + ny * ny + nz * nz)
    return np.stack([nx / l, ny / l, nz / l], -1) * .5 + .5

def guardar(a, ruta, px):
    modo = "L" if a.ndim == 2 else "RGB"
    im = Image.fromarray((np.clip(a, 0, 1) * 255 + .5).astype(np.uint8), modo)
    im = im.resize((px, px), Image.LANCZOS)
    im.save(ruta, "WEBP", quality=90, method=6)
    print("  ", ruta)

def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    op = {a.split("=")[0]: (a.split("=", 1)[1] if "=" in a else True) for a in sys.argv[1:] if a.startswith("--")}
    if len(args) < 3:
        print(__doc__)
        sys.exit(1)
    origen, salida, nombre = args
    px = int(op.get("--px", 1024))
    fuerza = float(op.get("--fuerza", 6))
    a = np.asarray(Image.open(origen).convert("RGB"), dtype=np.float32) / 255
    alt_px = None
    if op.get("--alturas"):
        alt_px = np.asarray(Image.open(op["--alturas"]).convert("L").resize(a.shape[1::-1], Image.LANCZOS), dtype=np.float32) / 255
    c = costura(a)
    print(f"{nombre}: costura al repetir ×{c:.2f} (1 = no se nota)")
    if c > 1.6 and "--sin-arreglo" not in op:
        print("   se arreglan los bordes")
        a = sin_costura(a)
        if alt_px is not None:
            alt_px = sin_costura(alt_px)
    brillo = None
    if "--todo-brilla" in op:
        brillo = np.clip(_gris(a) * 1.3, 0, 1)
    elif "--brillo" in op:
        brillo = mascara_brillo(a)
    alt = None
    if alt_px is not None:
        # ¿cuadra con el color? las piedras han de estar en el mismo sitio
        ref = alturas_del_color(a, brillo)
        corr = np.corrcoef(ref.ravel(), alt_px.ravel())[0, 1]
        print(f"   alturas de Pixmith: parecido con el color {corr:.2f}")
        if corr >= .35:
            alt = alt_px
        else:
            print("   AVISO: las alturas de Pixmith no cuadran con el color; se sacan del color")
    if alt is None:
        alt = alturas_del_color(a, brillo)
    rug = np.clip(.97 - alt * .3, .55, 1)
    if brillo is not None:
        rug = rug * (1 - brillo * .6)
    if "--mosaico" in op:
        ruta = op["--mosaico"] if isinstance(op["--mosaico"], str) else f"/tmp/{nombre}_mosaico.jpg"
        t = Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8)).resize((512, 512), Image.LANCZOS)
        m = Image.new("RGB", (1536, 1536))
        for j in range(3):
            for i in range(3):
                m.paste(t, (i * 512, j * 512))
        m.save(ruta, quality=88)
        print(f"   mosaico 3×3: {ruta} (costura que queda ×{costura(a):.2f})")
    guardar(a, f"{salida}/{nombre}_color.webp", px)
    guardar(normales(alt, fuerza), f"{salida}/{nombre}_normal.webp", px)
    guardar(rug, f"{salida}/{nombre}_rugosidad.webp", px)
    if brillo is not None:
        guardar(brillo, f"{salida}/{nombre}_brillo.webp", px)

if __name__ == "__main__":
    main()
