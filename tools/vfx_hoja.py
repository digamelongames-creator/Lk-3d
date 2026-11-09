#!/usr/bin/env python3
"""Hojas de fotogramas para los efectos (assets/vfx/<nombre>.png + <nombre>.json).

  python3 tools/vfx_hoja.py convertir <imagen.png> <nombre> [--cols=4] [--filas=4] [--fps=20] [--bucle] [--centrar]
      Convierte una hoja hecha con IA (ChatGPT) sobre fondo negro: la parte en la rejilla,
      recorta el borde de cada celda (por si trae líneas), quita el fondo (negro o gris oscuro),
      centra cada fotograma por su brillo si se pide y la deja en una rejilla de 256 px por celda.
      El alfa sale del brillo: el juego la pinta en modo aditivo (lo negro no suma nada).

  python3 tools/vfx_hoja.py lote <carpeta> [nombre…]
      Convierte de una vez todas las imágenes (.png, .gif, .webp, .jpg) de la carpeta (la de Diego, C:\\VFX_MAGIAS).
      El nombre del archivo es el de la hoja (mago_nova.png → assets/vfx/mago_nova.png). Si en el catálogo
      (assets/vfx/catalogo.json) hay una ficha con esa hoja, se usa su «bucle»; si no hay ninguna, se añade una
      ficha nueva de forma «golpe» para ajustarla luego con el panel (F4). El original se copia a tools/vfx_originales/.

  python3 tools/vfx_hoja.py provisional
      Dibuja por código las dos de la prueba (bola_fuego y explosion_fuego), para que el juego
      funcione antes de tener las de ChatGPT. Se sustituyen convirtiendo las buenas con el mismo nombre.
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

CELDA = 256
SALIDA = Path(__file__).resolve().parent.parent / "assets" / "vfx"


def _guardar(frames, nombre, cols, filas, fps, bucle, origen):
    SALIDA.mkdir(parents=True, exist_ok=True)
    hoja = np.zeros((filas * CELDA, cols * CELDA, 4), np.uint8)
    for i, f in enumerate(frames):
        r, c = divmod(i, cols)
        hoja[r * CELDA:(r + 1) * CELDA, c * CELDA:(c + 1) * CELDA] = f
    Image.fromarray(hoja, "RGBA").save(SALIDA / f"{nombre}.png", optimize=True)
    (SALIDA / f"{nombre}.json").write_text(json.dumps(
        {"cols": cols, "filas": filas, "fotogramas": len(frames), "fps": fps, "bucle": bucle, "origen": origen},
        ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f"{SALIDA / nombre}.png  ({cols}×{filas}, {len(frames)} fotogramas, {fps} fps{', en bucle' if bucle else ''})")


def _a_rgba(rgb):
    """rgb float 0..1 (fondo ya en negro) → RGBA uint8 con alfa = brillo"""
    a = np.clip(rgb.max(axis=2) * 1.15, 0, 1)
    out = np.zeros(rgb.shape[:2] + (4,), np.uint8)
    out[..., :3] = np.clip(rgb * 255, 0, 255)
    out[..., 3] = (a * 255).astype(np.uint8)
    return out


# ----------------------------------------------------------------------
#  convertir lo de ChatGPT
# ----------------------------------------------------------------------
def convertir(ruta, nombre, cols=4, filas=4, fps=20, bucle=False, centrar=False):
    fuente = Image.open(ruta)
    if getattr(fuente, "n_frames", 1) > 1:   # GIF animado: cada fotograma, una celda
        return _convertir_gif(fuente, nombre, cols, filas, fps, bucle, Path(ruta).name)
    img = np.asarray(fuente.convert("RGB")).astype(np.float32) / 255
    H, W = img.shape[:2]
    # fondo: la mediana del borde de la imagen (por si sale gris oscuro en vez de negro)
    borde = np.concatenate([img[:4].reshape(-1, 3), img[-4:].reshape(-1, 3), img[:, :4].reshape(-1, 3), img[:, -4:].reshape(-1, 3)])
    fondo = np.median(borde, axis=0)
    img = np.clip((img - fondo) / np.maximum(1 - fondo, 1e-3), 0, 1)
    # lo casi negro, a negro del todo (quita el grano de la compresión)
    lum = img.max(axis=2, keepdims=True)
    img = img * np.clip((lum - .04) / .08, 0, 1)
    frames = []
    for r in range(filas):
        for c in range(cols):
            y0, y1 = round(r * H / filas), round((r + 1) * H / filas)
            x0, x1 = round(c * W / cols), round((c + 1) * W / cols)
            m = max(2, round((x1 - x0) * .03))   # fuera las líneas de la rejilla
            cel = img[y0 + m:y1 - m, x0 + m:x1 - m].copy()
            if centrar:
                peso = cel.max(axis=2)
                if peso.sum() > 1:
                    yy, xx = np.indices(peso.shape)
                    dy = int(round(peso.shape[0] / 2 - (yy * peso).sum() / peso.sum()))
                    dx = int(round(peso.shape[1] / 2 - (xx * peso).sum() / peso.sum()))
                    cel = np.roll(np.roll(cel, dy, 0), dx, 1)
            # fundido suave hacia los bordes de la celda, para que no se vea el corte
            h, w = cel.shape[:2]
            yy, xx = np.indices((h, w))
            d = np.minimum.reduce([yy, xx, h - 1 - yy, w - 1 - xx]) / (min(h, w) * .08)
            cel *= np.clip(d, 0, 1)[..., None]
            cel = np.asarray(Image.fromarray((cel * 255).astype(np.uint8)).resize((CELDA, CELDA), Image.LANCZOS)).astype(np.float32) / 255
            frames.append(_a_rgba(cel))
    _guardar(frames, nombre, cols, filas, fps, bucle, Path(ruta).name)


def _limpiar(img):
    """quita el fondo (la mediana del borde) y deja lo casi negro en negro; img float 0..1"""
    borde = np.concatenate([img[:4].reshape(-1, 3), img[-4:].reshape(-1, 3), img[:, :4].reshape(-1, 3), img[:, -4:].reshape(-1, 3)])
    fondo = np.median(borde, axis=0)
    img = np.clip((img - fondo) / np.maximum(1 - fondo, 1e-3), 0, 1)
    lum = img.max(axis=2, keepdims=True)
    return img * np.clip((lum - .04) / .08, 0, 1)


def _convertir_gif(fuente, nombre, cols, filas, fps, bucle, origen):
    n = fuente.n_frames
    if n > cols * filas:
        print(f"aviso: el GIF tiene {n} fotogramas; se usan los {cols * filas} primeros")
        n = cols * filas
    if fuente.info.get("duration"):
        fps = max(1, round(1000 / fuente.info["duration"]))
    frames = []
    for k in range(n):
        fuente.seek(k)
        img = _limpiar(np.asarray(fuente.convert("RGB")).astype(np.float32) / 255)
        h, w = img.shape[:2]
        lado = max(h, w)   # a cuadrado, sin deformar
        cuad = np.zeros((lado, lado, 3), np.float32)
        cuad[(lado - h) // 2:(lado - h) // 2 + h, (lado - w) // 2:(lado - w) // 2 + w] = img
        cuad = np.asarray(Image.fromarray((cuad * 255).astype(np.uint8)).resize((CELDA, CELDA), Image.LANCZOS)).astype(np.float32) / 255
        frames.append(_a_rgba(cuad))
    _guardar(frames, nombre, cols, filas, fps, bucle, origen)


# ----------------------------------------------------------------------
#  provisionales, dibujadas por código
# ----------------------------------------------------------------------
def _ruido(rng, n, escala):
    """ruido suave de valores (varias octavas), n×n, 0..1"""
    tot = np.zeros((n, n), np.float32)
    amp, s = 1.0, escala
    for _ in range(4):
        g = rng.random((s + 1, s + 1)).astype(np.float32)
        tot += amp * np.asarray(Image.fromarray((g * 255).astype(np.uint8)).resize((n, n), Image.BICUBIC)).astype(np.float32) / 255
        amp *= .5
        s *= 2
    return tot / 1.875


def _fuego(t):
    """color del fuego según la intensidad t (0..1): rojo oscuro → naranja → amarillo → blanco"""
    t = np.clip(t, 0, 1)[..., None]
    c0 = np.array([.35, .03, .0]); c1 = np.array([1, .35, .04]); c2 = np.array([1, .78, .25]); c3 = np.array([1, .97, .85])
    return np.where(t < .35, c0 * (t / .35), np.where(t < .65, c0 + (c1 - c0) * ((t - .35) / .3),
                    np.where(t < .85, c1 + (c2 - c1) * ((t - .65) / .2), c2 + (c3 - c2) * ((t - .85) / .15))))


def provisional():
    rng = np.random.default_rng(7)
    n = CELDA
    yy, xx = (np.indices((n, n)).astype(np.float32) - n / 2) / (n / 2)
    # bola de fuego hacia la derecha: núcleo, llamas que se arremolinan y cola a la izquierda
    frames = []
    for k in range(16):
        ru = _ruido(rng, n, 6)
        ru2 = np.roll(_ruido(rng, n, 3), k * 6, axis=1)
        hx = .3
        atras = np.clip(hx - xx, 0, None)                    # cuánto se queda atrás (la cola)
        ancho = .3 * np.clip(1 - atras / 1.25, 0, 1) ** .8   # la cola se estrecha
        d = np.where(xx > hx, np.sqrt((xx - hx) ** 2 + yy ** 2) / .3, np.abs(yy) / np.maximum(ancho, 1e-3))
        llama = np.clip(1 - d + (ru - .5) * .7 + (ru2 - .5) * .35, 0, 1) * np.clip(1 - atras / 1.25, 0, 1)
        nucleo = np.clip(1 - np.sqrt((xx - hx) ** 2 + yy ** 2) / .22, 0, 1)
        t = np.clip(llama * .95 + nucleo * .7, 0, 1)
        rgb = _fuego(t) * np.clip(llama * 2.5 + nucleo, 0, 1)[..., None]
        frames.append(_a_rgba(rgb.astype(np.float32)))
    _guardar(frames, "bola_fuego", 4, 4, 18, True, "provisional (tools/vfx_hoja.py)")
    # explosión: destello, bola que crece, se rompe en brasas y humo y se apaga
    frames = []
    r = np.sqrt(xx ** 2 + yy ** 2)
    for k in range(16):
        p = k / 15
        ru = _ruido(rng, n, 5)
        radio = .25 + .65 * (1 - (1 - min(1, p * 1.6)) ** 2.2)
        cuerpo = np.clip((1 - r / radio) * 2.2 + (ru - .5) * (.8 + p), 0, 1)
        hueco = np.clip((r / radio - (p - .35) * 1.3) * 2.5, 0, 1) if p > .35 else 1   # se abre por dentro
        calor = np.clip(1.15 - p * 1.1, 0, 1)
        destello = np.clip(1 - r / .45, 0, 1) * max(0, 1 - p * 5)
        t = np.clip(cuerpo * calor + destello, 0, 1)
        vida = np.clip(1.25 - p * 1.25, 0, 1) ** .7
        rgb = _fuego(t) * (cuerpo * hueco * vida)[..., None] + destello[..., None]
        frames.append(_a_rgba(np.clip(rgb, 0, 1).astype(np.float32)))
    _guardar(frames, "explosion_fuego", 4, 4, 24, False, "provisional (tools/vfx_hoja.py)")


def provisional_mago():
    """las del mago que aún no ha hecho Diego (no pisa las que ya existen)"""
    rng = np.random.default_rng(11)
    n = CELDA
    yy, xx = (np.indices((n, n)).astype(np.float32) - n / 2) / (n / 2)
    r = np.sqrt(xx ** 2 + yy ** 2)
    ang = np.arctan2(yy, xx)
    def hecha(nombre):
        return (SALIDA / f"{nombre}.png").exists()
    if not hecha("mago_nova"):   # anillo de fuego visto desde arriba, en bucle
        fr = []
        for k in range(16):
            ru = _ruido(rng, n, 6)
            onda = .5 + .5 * np.sin(ang * 9 + k / 16 * 2 * np.pi)
            anillo = np.clip(1 - np.abs(r - .8) / (.1 + .06 * onda), 0, 1)
            t = np.clip(anillo * (.75 + .5 * ru), 0, 1)
            fr.append(_a_rgba((_fuego(t) * np.clip(t * 1.8, 0, 1)[..., None]).astype(np.float32)))
        _guardar(fr, "mago_nova", 4, 4, 14, True, "provisional (tools/vfx_hoja.py)")
    if not hecha("mago_llamarada"):   # onda de fuego que se abre, desde arriba
        fr = []
        for k in range(16):
            p = k / 15
            ru = _ruido(rng, n, 6)
            rad = .1 + .85 * (1 - (1 - p) ** 2)
            anillo = np.clip(1 - np.abs(r - rad) / (.18 - .1 * p), 0, 1)
            t = np.clip(anillo * (1.1 - p) + (ru - .5) * .3 * anillo, 0, 1)
            fr.append(_a_rgba((_fuego(t) * np.clip(t * 2, 0, 1)[..., None] * (1 - p ** 2)).astype(np.float32)))
        _guardar(fr, "mago_llamarada", 4, 4, 22, False, "provisional (tools/vfx_hoja.py)")
    if not hecha("mago_llamas"):   # columna de llamas, de lado, en bucle
        fr = []
        for k in range(16):
            ru = np.roll(_ruido(rng, n, 5), -k * 10, axis=0)
            subir = np.clip((yy + 1) / 2, 0, 1)   # 0 arriba, 1 abajo
            ancho = .18 + .22 * subir
            cuerpo = np.clip(1 - np.abs(xx) / ancho, 0, 1) * subir ** .6
            t = np.clip(cuerpo * (.6 + .8 * ru) * 1.2, 0, 1)
            fr.append(_a_rgba((_fuego(t) * np.clip(t * 1.6, 0, 1)[..., None]).astype(np.float32)))
        _guardar(fr, "mago_llamas", 4, 4, 16, True, "provisional (tools/vfx_hoja.py)")
    if not hecha("mago_teletransporte"):   # columna de luz dorada que se abre y se cierra
        fr = []
        for k in range(16):
            p = k / 15
            ru = _ruido(rng, n, 6)
            ancho = .04 + .32 * np.sin(np.pi * min(1, p * 1.3)) ** .7
            col = np.clip(1 - np.abs(xx) / max(ancho, .02), 0, 1) * np.clip(1 - np.abs(yy) / .95, 0, 1) ** .5
            t = np.clip(col * (1.15 - p) + (ru - .5) * .25 * col, 0, 1)
            oro = np.stack([t, t * .8, t * .35], -1) + _fuego(t) * .3
            fr.append(_a_rgba(np.clip(oro * np.clip(t * 2, 0, 1)[..., None], 0, 1).astype(np.float32)))
        _guardar(fr, "mago_teletransporte", 4, 4, 22, False, "provisional (tools/vfx_hoja.py)")


RAIZ = Path(__file__).resolve().parent.parent
CATALOGO = RAIZ / "assets" / "vfx" / "catalogo.json"
ORIGINALES = RAIZ / "tools" / "vfx_originales"
EXT = {".png", ".gif", ".webp", ".jpg", ".jpeg"}


def _leer_catalogo():
    return json.loads(CATALOGO.read_text(encoding="utf-8")) if CATALOGO.exists() else {}


def _escribir_catalogo(cat):
    lineas = [f" {json.dumps(k, ensure_ascii=False)}: {json.dumps(v, ensure_ascii=False)}" for k, v in cat.items()]
    CATALOGO.write_text("{\n" + ",\n".join(lineas) + "\n}\n", encoding="utf-8")


def lote(carpeta, solo=None):
    import shutil
    cat = _leer_catalogo()
    nuevas = []
    archivos = sorted(p for p in Path(carpeta).iterdir() if p.suffix.lower() in EXT)
    if solo:
        archivos = [p for p in archivos if p.stem.lower() in solo]
    for ruta in archivos:
        nombre = ruta.stem.lower().replace(" ", "_").replace("-", "_")
        fichas = [d for d in cat.values() if d.get("hoja") == nombre]
        bucle = any(d.get("bucle", False) for d in fichas)
        try:
            convertir(str(ruta), nombre, bucle=bucle)
        except Exception as e:   # una mala no para las demás
            print(f"  ERROR con {ruta.name}: {e}")
            continue
        ORIGINALES.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ruta, ORIGINALES / (nombre + "_chatgpt" + ruta.suffix.lower()))
        if not fichas:
            cat[nombre] = {"nombre": nombre.replace("_", " ").capitalize(), "hoja": nombre, "forma": "golpe", "tam": 2.5,
                           "brillo": 1.0, "velocidad": 1.0, "alto": 1.0, "luz": "#ffa040", "luz_energia": 4.0, "luz_alcance": 5.0, "sonido": ""}
            nuevas.append(nombre)
    if nuevas:
        _escribir_catalogo(cat)
        print("fichas nuevas en el catálogo (forma «golpe», ajústalas con F4):", ", ".join(nuevas))
    print(f"{len(archivos)} imágenes convertidas")


if __name__ == "__main__":
    a = sys.argv[1:]
    if not a:
        print(__doc__)
        sys.exit(1)
    if a[0] == "provisional":
        provisional()
    elif a[0] == "provisional_mago":
        provisional_mago()
    elif a[0] == "lote" and len(a) >= 2:
        lote(a[1], set(x.lower() for x in a[2:]) or None)
    elif a[0] == "convertir" and len(a) >= 3:
        op = {k.lstrip("-").split("=")[0]: (k.split("=")[1] if "=" in k else True) for k in a[3:]}
        convertir(a[1], a[2], int(op.get("cols", 4)), int(op.get("filas", 4)), int(op.get("fps", 20)),
                  bool(op.get("bucle", False)), bool(op.get("centrar", False)))
    else:
        print(__doc__)
        sys.exit(1)
