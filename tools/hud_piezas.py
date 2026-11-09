#!/usr/bin/env python3
"""Piezas del HUD hechas por Diego en ChatGPT → assets/ui/*.png + assets/ui/medidas.json.

Uso: python3 tools/hud_piezas.py <carpeta con los PNG de Diego> assets/ui

- Recorta cada pieza a lo que tiene dibujado y la escala a un tamaño de trabajo.
- Las que vienen con fondo negro (sin transparencia) se pasan a transparencia por su brillo.
- La barra de experiencia viene con marco y relleno en la misma imagen: se parte en dos.
- medidas.json guarda el hueco de cada marco (en fracciones de la imagen), que es lo que usa UiArte.
Si una pieza no está en la carpeta, se salta y el juego usa su reserva.
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

# nombre del archivo de Diego (empieza por) → (nombre en el juego, ancho máximo)
PIEZAS = {
    "Marco de interfaz fantástica con estatua de mármol": ("orbe_marco_izq", 640),
    "Marco ornamental dorado con estatua clásica": ("orbe_marco_der", 640),
    "Esfera de gel rojo incandescente": ("orbe_vida_liquido", 512),
    "Esfera de gel azul": ("orbe_mana_liquido", 512),
    "Marco de piedra y oro con estatuas marmóreas": ("inventario_marco", 1024),
    "Panel ornamental de mármol negro": ("panel", 760),
    "Marco dorado ornamentado sobre piedra oscura": ("hueco_habilidad", 256),
    "Ranura de inventario dorada vacía": ("hueco_objeto", 256),
    "Marco dorado ornamentado para inventario": ("hueco_dorado", 256),
    "Marco mágico azul": ("hueco_magico", 256),
    "Marco legendario": ("hueco_legendario", 256),
    "Marco del minimapa": ("minimapa_marco", 512),
    "Barra de habilidades": ("barra_habilidades", 1200),
}

# botones (normal, al pasar el ratón y pulsado): se guardan a dos altos, el normal y el chico
BOTONES = {
    "Botón normal": "boton_normal",
    "Botón encima": "boton_encima",
    "Botón pulsado": "boton_pulsado",
}
ALTO_BOTON = 56
ALTO_CHICO = 32


def sin_fondo_negro(im: Image.Image) -> Image.Image:
    """Fondo negro → transparente: alfa por brillo y color sin premultiplicar."""
    a = np.asarray(im.convert("RGB")).astype(np.float32) / 255
    al = np.clip((a.max(2) - .04) / .22, 0, 1)
    rgb = np.where(al[..., None] > 0, np.clip(a / np.maximum(al[..., None], 1e-3), 0, 1), 0)
    out = np.dstack([rgb, al]) * 255
    return Image.fromarray(out.astype(np.uint8), "RGBA")


def preparar(im: Image.Image) -> Image.Image:
    im = im.convert("RGBA") if im.mode == "RGBA" else sin_fondo_negro(im)
    a = np.asarray(im)[:, :, 3]
    ys, xs = np.where(a > 12)
    return im.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))


def escalar(im: Image.Image, ancho: int) -> Image.Image:
    if im.width <= ancho:
        return im
    return im.resize((ancho, round(im.height * ancho / im.width)), Image.LANCZOS)


def hueco(im: Image.Image):
    """El mayor agujero transparente que no toca el borde, en fracciones [x0, y0, x1, y1]."""
    a = np.asarray(im)[:, :, 3]
    lab, n = ndimage.label(a < 20)
    borde = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]])).tolist())
    mejor, tam = 0, 0
    for i in range(1, n + 1):
        if i in borde:
            continue
        s = int((lab == i).sum())
        if s > tam:
            mejor, tam = i, s
    if not mejor:
        return None
    ys, xs = np.where(lab == mejor)
    return [round(xs.min() / im.width, 4), round(ys.min() / im.height, 4),
            round((xs.max() + 1) / im.width, 4), round((ys.max() + 1) / im.height, 4)]


def main(src: Path, dst: Path) -> None:
    dst.mkdir(parents=True, exist_ok=True)
    medidas_f = dst / "medidas.json"
    medidas = json.loads(medidas_f.read_text()) if medidas_f.exists() else {}
    archivos = sorted(src.glob("*.png"))
    for pref, (nombre, ancho) in PIEZAS.items():
        f = next((x for x in archivos if x.stem.startswith(pref)), None)
        if f is None:
            continue
        im = escalar(preparar(Image.open(f)), ancho)
        im.save(dst / f"{nombre}.png", optimize=True)
        h = hueco(im) if nombre.endswith("marco") or nombre.startswith("orbe_marco") or nombre == "minimapa_marco" else None
        medidas[nombre] = {"tam": [im.width, im.height], **({"hueco": h} if h else {})}
        print(f"{f.name} → {nombre}.png {im.size} {h or ''}")
    for pref, nombre in BOTONES.items():
        f = next((x for x in archivos if x.stem.startswith(pref)), None)
        if f is None:
            continue
        im = preparar(Image.open(f))
        # fuera los adornos sueltos de arriba o abajo: solo las filas con bastante dibujo
        a = np.asarray(im)[:, :, 3]
        filas = np.where((a > 40).sum(1) > im.width * .2)[0]
        im = im.crop((0, filas.min(), im.width, filas.max() + 1))
        for suf, alto in (("", ALTO_BOTON), ("_chico", ALTO_CHICO)):
            b = im.resize((round(im.width * alto / im.height), alto), Image.LANCZOS)
            b.save(dst / f"{nombre}{suf}.png", optimize=True)
            medidas[nombre + suf] = {"tam": [b.width, b.height]}
            print(f"{f.name} → {nombre}{suf}.png {b.size}")
    # barra de experiencia: marco arriba y relleno abajo en la misma imagen
    f = next((x for x in archivos if x.stem.startswith("Barra de experiencia")), None)
    if f is not None:
        im = Image.open(f)
        im = im.convert("RGBA") if im.mode == "RGBA" else sin_fondo_negro(im)
        a = np.asarray(im)[:, :, 3]
        filas = (a > 30).sum(1) > 20
        bandas, y0 = [], None
        for y, v in enumerate(filas):
            if v and y0 is None:
                y0 = y
            if not v and y0 is not None:
                bandas.append((y0, y))
                y0 = None
        bandas = sorted(bandas, key=lambda b: b[0])[:2]
        for (b0, b1), nombre in zip(bandas, ["exp_marco", "exp_relleno"]):
            pieza = preparar(im.crop((0, b0, im.width, b1)))
            pieza = escalar(pieza, 1100)
            pieza.save(dst / f"{nombre}.png", optimize=True)
            medidas[nombre] = {"tam": [pieza.width, pieza.height]}
            print(f"{f.name} → {nombre}.png {pieza.size}")
    medidas_f.write_text(json.dumps(medidas, indent=1, ensure_ascii=False))


if __name__ == "__main__":
    main(Path(sys.argv[1]), Path(sys.argv[2]))
