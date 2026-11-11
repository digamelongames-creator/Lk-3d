#!/usr/bin/env python3
"""Herramientas para montar escenas a partir de una imagen de referencia (ver docs/ESCENAS.md).

    python3 tools/escena.py camara <escena> <puntos.json> [--fov=45] [--ancho=1536 --alto=1024]
        Calcula la cámara que hizo la imagen a partir de puntos conocidos y la guarda en assets/escenas/<escena>.json.
        puntos.json: [{"mundo": [x, y, z], "imagen": [px, py]}, …]  (6 o más; mejor repartidos por toda la imagen)
        Cámara propia (perspectiva): ajusta posición, punto al que mira y, si no se da --fov, también el campo de visión.
        Cámara del juego («camara.tipo» = "juego": ortográfica, giro 45°, inclinación 33°): ajusta el centro y el zoom.

    python3 tools/escena.py colocar <escena> <px> <py> <altura>  [--ancho=… --alto=…]
        Dónde cae en el mundo el punto (px, py) de la imagen a esa altura (y). Para poner «la jaula aquí, a 8 m».

    python3 tools/escena.py proyectar <escena> <x> <y> <z>
        Dónde sale en la imagen un punto del mundo (para comprobar antes de capturar).

    python3 tools/escena.py comparar <referencia.png> <captura.png> [--salida=comparacion.png] [--informe=…json]
        Nota de parecido (0–100) por zonas (rejilla 3×3): brillo, color, contraste y detalle. Guarda la referencia y la
        captura una encima de otra con la nota de cada zona, y (con --informe) añade la nota al informe de la captura.
"""
import json
import math
import os
import sys

import numpy as np

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GIRO_JUEGO = 45.0
INCLINACION_JUEGO = 33.0


def ruta_escena(nombre):
    return os.path.join(RAIZ, "assets", "escenas", nombre + ".json")


def leer(nombre):
    return json.load(open(ruta_escena(nombre), encoding="utf-8"))


def guardar_camara(nombre, cam):
    """cambia solo la línea de la cámara (el archivo tiene un objeto por línea)"""
    r = ruta_escena(nombre)
    lineas = open(r, encoding="utf-8").read().split("\n")
    for i, l in enumerate(lineas):
        if l.strip().startswith('"camara"'):
            lineas[i] = '\t"camara": ' + json.dumps(cam, ensure_ascii=False) + ","
    open(r, "w", encoding="utf-8").write("\n".join(lineas))


# ---------------------------------------------------------------- cámaras
def _base(desde, hacia):
    f = np.asarray(hacia, float) - np.asarray(desde, float)
    f /= np.linalg.norm(f)
    r = np.cross(f, [0, 1, 0])
    r /= np.linalg.norm(r)
    u = np.cross(r, f)
    return f, r, u


def camara_juego(cam):
    """la cámara del juego como desde/hacia: mira al centro con giro 45° e inclinación 33° (ortográfica)"""
    c = np.asarray(cam.get("centro", [0, 0, 0]), float)
    g = math.radians(cam.get("giro", GIRO_JUEGO))
    i = math.radians(cam.get("inclinacion", INCLINACION_JUEGO))
    a = np.array([math.sin(g), 0, math.cos(g)])   # del objetivo hacia la cámara (CamaraIso.hacia_camara)
    vista = np.array([a[0] * math.cos(i), math.sin(i), a[2] * math.cos(i)])
    return c + vista * 40.0, c


def proyectar(cam, p, ancho, alto):
    if cam.get("tipo") == "juego":
        desde, hacia = camara_juego(cam)
        f, r, u = _base(desde, hacia)
        d = np.asarray(p, float) - desde
        k = alto / float(cam.get("zoom", 17.0))   # px por metro
        return ancho / 2 + d @ r * k, alto / 2 - d @ u * k
    desde, hacia = np.asarray(cam["desde"], float), np.asarray(cam["hacia"], float)
    f, r, u = _base(desde, hacia)
    d = np.asarray(p, float) - desde
    t = math.tan(math.radians(cam.get("fov", 45.0)) / 2)
    return ancho / 2 + (d @ r) / (d @ f) / t * alto / 2, alto / 2 - (d @ u) / (d @ f) / t * alto / 2


def rayo(cam, px, py, y, ancho, alto):
    if cam.get("tipo") == "juego":
        desde, hacia = camara_juego(cam)
        f, r, u = _base(desde, hacia)
        k = alto / float(cam.get("zoom", 17.0))
        o = desde + r * (px - ancho / 2) / k + u * (alto / 2 - py) / k
        d = f
    else:
        desde, hacia = np.asarray(cam["desde"], float), np.asarray(cam["hacia"], float)
        f, r, u = _base(desde, hacia)
        t = math.tan(math.radians(cam.get("fov", 45.0)) / 2)
        o = desde
        d = f + r * (px - ancho / 2) / (alto / 2) * t + u * (alto / 2 - py) / (alto / 2) * t
    s = (y - o[1]) / d[1]
    return o + d * s


def ajustar(cam, puntos, ancho, alto, fov_fijo):
    from scipy.optimize import least_squares
    if cam.get("tipo") == "juego":
        def res(v):
            c = dict(cam, centro=[v[0], 0, v[1]], zoom=v[2])
            return np.concatenate([np.array(proyectar(c, p["mundo"], ancho, alto)) - p["imagen"] for p in puntos])
        c0 = np.mean([p["mundo"] for p in puntos], axis=0)
        v = least_squares(res, [c0[0], c0[2], float(cam.get("zoom", 17.0))]).x
        nueva = dict(cam, centro=[round(v[0], 2), 0, round(v[1], 2)], zoom=round(v[2], 2))
    else:
        def res(v):
            c = {"tipo": "propia", "desde": v[:3], "hacia": v[3:6], "fov": fov_fijo or v[6]}
            return np.concatenate([np.array(proyectar(c, p["mundo"], ancho, alto)) - p["imagen"] for p in puntos])
        c0 = np.mean([p["mundo"] for p in puntos], axis=0)
        ini = list(cam.get("desde", c0 + [0, 25, 25])) + list(cam.get("hacia", c0)) + ([] if fov_fijo else [cam.get("fov", 45.0)])
        lo = [-500] * 6 + ([] if fov_fijo else [15])
        hi = [500] * 6 + ([] if fov_fijo else [90])
        v = least_squares(res, ini, bounds=(lo, hi)).x
        nueva = {"tipo": "propia", "desde": [round(x, 2) for x in v[:3]], "hacia": [round(x, 2) for x in v[3:6]],
                 "fov": round(fov_fijo or v[6], 1)}
    err = [np.hypot(*(np.array(proyectar(nueva, p["mundo"], ancho, alto)) - p["imagen"])) for p in puntos]
    return nueva, err


# ---------------------------------------------------------------- comparación
def _cargar(ruta, tam=None):
    from PIL import Image
    im = Image.open(ruta).convert("RGB")
    if tam:
        im = im.resize(tam, Image.LANCZOS)
    return im


def _medidas(a):
    """brillo, color medio (relativo), contraste y detalle (bordes) de una zona"""
    g = a[..., 0] * .299 + a[..., 1] * .587 + a[..., 2] * .114
    s = a.sum(-1, keepdims=True) + 1e-3
    color = (a / s).reshape(-1, 3).mean(0)
    bordes = np.abs(np.diff(g, axis=0)).mean() + np.abs(np.diff(g, axis=1)).mean()
    return g.mean(), color, g.std(), bordes


def comparar(ref, cap, salida=None, informe=None):
    from PIL import Image, ImageDraw
    B = _cargar(cap)
    A = _cargar(ref, B.size)
    a = np.asarray(A, float) / 255
    b = np.asarray(B, float) / 255
    H, W = a.shape[:2]
    zonas = []
    for j in range(3):
        for i in range(3):
            za = a[j * H // 3:(j + 1) * H // 3, i * W // 3:(i + 1) * W // 3]
            zb = b[j * H // 3:(j + 1) * H // 3, i * W // 3:(i + 1) * W // 3]
            ma, mb = _medidas(za), _medidas(zb)
            brillo = max(0, 1 - abs(ma[0] - mb[0]) / .35)
            color = max(0, 1 - np.abs(ma[1] - mb[1]).sum() / .25)
            contraste = max(0, 1 - abs(ma[2] - mb[2]) / .2)
            detalle = max(0, 1 - abs(ma[3] - mb[3]) / max(ma[3], .02))
            nota = 100 * (.3 * brillo + .3 * color + .2 * contraste + .2 * detalle)
            zonas.append({"zona": f"{'arriba centro abajo'.split()[j]}-{'izquierda centro derecha'.split()[i]}",
                          "nota": round(nota), "brillo": round(100 * brillo), "color": round(100 * color),
                          "contraste": round(100 * contraste), "detalle": round(100 * detalle),
                          "mas_claro": bool(mb[0] > ma[0] + .03), "mas_oscuro": bool(mb[0] < ma[0] - .03)})
    total = round(sum(z["nota"] for z in zonas) / 9)
    if salida:
        lienzo = Image.new("RGB", (W, H * 2))
        lienzo.paste(A, (0, 0))
        lienzo.paste(B, (0, H))
        d = ImageDraw.Draw(lienzo)
        for k, z in enumerate(zonas):
            i, j = k % 3, k // 3
            x, y = i * W // 3, H + j * H // 3
            d.rectangle([x, y, x + W // 3, y + H // 3], outline=(255, 255, 255))
            d.text((x + 8, y + 8), f"{z['nota']}", fill=(255, 255, 0))
        d.text((10, H + H - 24), f"nota {total}/100", fill=(255, 255, 0))
        lienzo.resize((W // 2, H)).save(salida)
    res = {"nota": total, "zonas": zonas, "referencia": ref, "captura": cap}
    if informe and os.path.exists(informe):
        inf = json.load(open(informe))
        inf["parecido"] = res
        json.dump(inf, open(informe, "w"), indent=2, ensure_ascii=False)
    return res


# ---------------------------------------------------------------- main
def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    op = {a.split("=")[0]: (a.split("=", 1)[1] if "=" in a else True) for a in sys.argv[1:] if a.startswith("--")}
    ancho, alto = int(op.get("--ancho", 1536)), int(op.get("--alto", 1024))
    if not args:
        print(__doc__)
        return
    cmd = args[0]
    if cmd == "camara":
        E = leer(args[1])
        puntos = json.load(open(args[2]))
        for p in puntos:
            p["imagen"] = np.asarray(p["imagen"], float)
        cam, err = ajustar(E.get("camara", {"tipo": "propia"}), puntos, ancho, alto, float(op["--fov"]) if "--fov" in op else None)
        guardar_camara(args[1], cam)
        print("cámara:", json.dumps(cam))
        print("error por punto (px):", [round(e) for e in err], " máximo", round(max(err)))
    elif cmd == "colocar":
        E = leer(args[1])
        p = rayo(E["camara"], float(args[2]), float(args[3]), float(args[4]), ancho, alto)
        print(json.dumps([round(float(x), 2) for x in p]))
    elif cmd == "proyectar":
        E = leer(args[1])
        x, y = proyectar(E["camara"], [float(v) for v in args[2:5]], ancho, alto)
        print(round(x), round(y))
    elif cmd == "comparar":
        r = comparar(args[1], args[2], op.get("--salida"), op.get("--informe"))
        print(f"nota {r['nota']}/100")
        for z in r["zonas"]:
            extra = " (más clara)" if z["mas_claro"] else " (más oscura)" if z["mas_oscuro"] else ""
            print(f"  {z['zona']:22s} {z['nota']:3d}  brillo {z['brillo']:3d} color {z['color']:3d} contraste {z['contraste']:3d} detalle {z['detalle']:3d}{extra}")
    else:
        print(__doc__)


if __name__ == "__main__":
    main()
