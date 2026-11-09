"""Kit de la ciudad de Inca, generado por código en Blender (mismo estilo que kit_mazmorra.py).

Uso:  python3 tools/blender/kit_ciudad.py  [salida.glb]      (módulo bpy: pip install bpy)

Cada pieza es un objeto con el nombre que espera Godot (Ciudad3D). Medidas en metros, el suelo en z = 0,
la pieza centrada en el origen y con el frente (puerta, cara) mirando a -Y de Blender = +Z de Godot (sur).
Los materiales los pone Godot por nombre (Ciudad3D.material): piedra, revoque, teja, madera, hierro,
ventana, agua, tela_roja, tela_azul, runa, brasa, vidrio_*, oro, adoquin, junta, hoja, corteza.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit_mazmorra as K  # noqa: E402  (Pieza, material, hiladas; también carga bpy)

import bpy  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

R = K.R
BL = K.BLOQUE
J = K.JUNTA


def mat(nombre, color, **kw):
    return K.material(nombre, color, **kw)


PIEDRA = lambda: mat("piedra", (0.42, 0.37, 0.33))  # noqa: E731
REVOQUE = lambda: mat("revoque", (0.8, 0.74, 0.62))  # noqa: E731
TEJA = lambda: mat("teja", (0.5, 0.22, 0.14))  # noqa: E731
MADERA = lambda: mat("madera", (0.30, 0.18, 0.09))  # noqa: E731
HIERRO = lambda: mat("hierro", (0.12, 0.11, 0.1), rugosidad=.5, metal=.8)  # noqa: E731
VENTANA = lambda: mat("ventana", (1.0, 0.6, 0.25), emision=(1.0, 0.55, 0.2))  # noqa: E731


def tono(v=0.12):
    k = 1 + R.uniform(-v, v)
    return (k, k, k)


def prisma(p, pts, y0, y1, m, color=(1, 1, 1)):
    """sólido de caras planas: el polígono pts [(x, z)] extruido de y0 a y1 (a lo largo de Y)"""
    bm = p.bm
    idx = p._mat(m)
    a = [bm.verts.new((x, y0, z)) for x, z in pts]
    b = [bm.verts.new((x, y1, z)) for x, z in pts]
    caras = [bm.faces.new(a), bm.faces.new(list(reversed(b)))]
    n = len(pts)
    for i in range(n):
        j = (i + 1) % n
        caras.append(bm.faces.new((a[i], b[i], b[j], a[j])))
    for f in caras:
        f.material_index = idx
        for lo in f.loops:
            lo[p.col] = (*color, 1.0)
    bmesh.ops.recalc_face_normals(bm, faces=caras)


def girar_pieza(p, grados):
    bmesh.ops.rotate(p.bm, verts=list(p.bm.verts), cent=(0, 0, 0), matrix=Matrix.Rotation(math.radians(grados), 3, "Z"))


# ---------------------------------------------------------------- muros de sillares
def lienzo(p, x0, x1, y, z0, z1, m, cara=-1, huecos=()):
    """lienzo de bloques a lo largo de X (de x0 a x1), en el plano y, con huecos [(xa, xb, za, zb)]"""
    z = z0
    fila = 0
    for h in K.hiladas(z1 - z0, .32, .46):
        x = x0 - (BL * .5 if fila % 2 else 0)
        while x < x1 - .02:
            largo = R.uniform(.45, .8)
            xa, xb = max(x, x0), min(x + largo, x1)
            x += largo
            if xb - xa < .08:
                continue
            cx, cz = (xa + xb) / 2, z + h / 2
            if any(ha - .02 < cx < hb + .02 and za - .02 < cz < zb + .02 for ha, hb, za, zb in huecos):
                continue
            p.caja((cx, y, cz), (xb - xa - J, .34, h - J), m)
        z += h
        fila += 1


def muros_casa(p, ancho, fondo, z0, z1, m, huecos_frente=(), huecos_lado=()):
    """cuatro lienzos de bloques alrededor de un rectángulo ancho × fondo"""
    lienzo(p, -ancho / 2, ancho / 2, -fondo / 2 + .17, z0, z1, m, huecos=huecos_frente)
    lienzo(p, -ancho / 2, ancho / 2, fondo / 2 - .17, z0, z1, m)
    # los lados: se hacen a lo largo de X y se giran 90°
    for lado in (-1, 1):
        q = K.Pieza("tmp")
        lienzo(q, -fondo / 2 + .34, fondo / 2 - .34, 0, z0, z1, m, huecos=huecos_lado)
        bmesh.ops.rotate(q.bm, verts=list(q.bm.verts), cent=(0, 0, 0), matrix=Matrix.Rotation(math.radians(90), 3, "Z"))
        bmesh.ops.translate(q.bm, vec=(lado * (ancho / 2 - .17), 0, 0), verts=list(q.bm.verts))
        _juntar(p, q)
    p.caja((0, 0, (z0 + z1) / 2), (ancho - .6, fondo - .6, z1 - z0), m, bisel=0, color=(.3, .27, .25), desorden=False)


def _juntar(p, q):
    me = bpy.data.meshes.new("tmp")
    q.bm.to_mesh(me)
    q.bm.free()
    antes = set(p.bm.faces)
    p.bm.from_mesh(me)
    bpy.data.meshes.remove(me)
    col_q = None
    nuevas = [f for f in p.bm.faces if f not in antes]
    # los materiales de q pasan con su índice: se remapean por nombre
    for f in nuevas:
        mq = q.mats[f.material_index] if f.material_index < len(q.mats) else q.mats[0]
        f.material_index = p._mat(mq)
    del col_q


def ventana(p, x, y, z, ancho=.7, alto=.9, cara=-1):
    """ventana con luz cálida, marco de madera y alféizar (en el plano y, mirando a cara·Y)"""
    p.caja((x, y, z), (ancho, .1, alto), VENTANA(), bisel=.01, desorden=False, color=(1, 1, 1))
    for dx in (-ancho / 2, ancho / 2):
        p.caja((x + dx, y + cara * .06, z), (.1, .12, alto + .1), MADERA(), bisel=.015, desorden=False, color=tono())
    p.caja((x, y + cara * .06, z), (.06, .1, alto), MADERA(), bisel=.01, desorden=False, color=tono())
    p.caja((x, y + cara * .06, z + alto / 2), (ancho + .14, .14, .1), MADERA(), bisel=.015, desorden=False, color=tono())
    p.caja((x, y + cara * .1, z - alto / 2 - .05), (ancho + .26, .26, .1), PIEDRA(), bisel=.02, desorden=False)


def puerta(p, x, y, ancho=1.1, alto=2.0, cara=-1):
    p.caja((x, y, alto / 2), (ancho, .14, alto), MADERA(), bisel=.02, desorden=False, color=(.75, .75, .75))
    for k in range(4):
        p.caja((x - ancho / 2 + (k + .5) * ancho / 4, y + cara * .08, alto / 2), (ancho / 4 - .03, .06, alto - .06), MADERA(),
               bisel=.015, desorden=False, color=tono(.18))
    for z in (.45, alto - .45):
        p.caja((x, y + cara * .12, z), (ancho - .05, .03, .08), HIERRO(), bisel=.005, desorden=False)
    p.cilindro((x + ancho * .3, y + cara * .13, alto * .5), .04, .04, HIERRO(), segmentos=8)
    # dintel y jambas de piedra
    p.caja((x, y + cara * .05, alto + .14), (ancho + .5, .4, .28), PIEDRA(), bisel=.04)
    for lado in (-1, 1):
        p.caja((x + lado * (ancho / 2 + .13), y + cara * .05, alto / 2), (.26, .4, alto), PIEDRA(), bisel=.04)


def tejado(p, ancho, fondo, z0, subida, vuelo=.45):
    """tejado a dos aguas con la cumbrera a lo largo de X: filas de tejas y los hastiales de revoque"""
    medio = fondo / 2 + vuelo
    pend = math.atan2(subida, fondo / 2)
    largo = math.hypot(subida, fondo / 2) + vuelo / math.cos(pend)
    filas = max(4, int(largo / .32))
    for lado in (-1, 1):
        for k in range(filas):
            t = (k + .5) / filas
            # desde el alero (t=0) a la cumbrera (t=1)
            y = lado * (medio - t * medio)
            z = z0 - vuelo * math.tan(pend) + t * (subida + vuelo * math.tan(pend))
            x = -ancho / 2 - vuelo
            while x < ancho / 2 + vuelo - .05:
                seg = R.uniform(.5, .9)
                xb = min(x + seg, ancho / 2 + vuelo)
                c = 1 + R.uniform(-.16, .16)
                p.caja(((x + xb) / 2, y, z + .08), (xb - x - .02, largo / filas + .1, .07), TEJA(), bisel=.02,
                       giro=(-lado * pend, 0, 0), desorden=False, color=(c, c * (1 + R.uniform(-.05, .05)), c))
                x = xb
        # tablero macizo debajo de las tejas (para que no se vea por los huecos)
        ye = lado * medio
        ze = z0 - vuelo * math.tan(pend)
        q = K.Pieza("tmp")
        prisma(q, [(ye, ze), (0, z0 + subida), (0, z0 + subida - .12), (ye, ze - .12)], -ancho / 2 - vuelo, ancho / 2 + vuelo, TEJA(), color=(.55, .55, .55))
        # prisma extruye a lo largo de Y: se gira para que el perfil quede en el plano YZ
        bmesh.ops.rotate(q.bm, verts=list(q.bm.verts), cent=(0, 0, 0), matrix=Matrix.Rotation(math.radians(90), 3, "Z"))
        bmesh.ops.scale(q.bm, vec=(-1, 1, 1), verts=list(q.bm.verts))
        bmesh.ops.recalc_face_normals(q.bm, faces=list(q.bm.faces))
        _juntar(p, q)
    # cumbrera
    p.caja((0, 0, z0 + subida + .1), (ancho + 2 * vuelo, .26, .16), TEJA(), bisel=.05, desorden=False, color=(.7, .7, .7))
    # hastiales
    for lado in (-1, 1):
        x = lado * (ancho / 2 - .17)
        q = K.Pieza("tmp")
        prisma(q, [(-fondo / 2 + .02, z0), (fondo / 2 - .02, z0), (0, z0 + subida - .02)], -.15, .15, REVOQUE(), color=(.95, .95, .95))
        bmesh.ops.rotate(q.bm, verts=list(q.bm.verts), cent=(0, 0, 0), matrix=Matrix.Rotation(math.radians(90), 3, "Z"))
        bmesh.ops.translate(q.bm, vec=(x, 0, 0), verts=list(q.bm.verts))
        _juntar(p, q)
        # viga del hastial
        p.caja((x + lado * .06, 0, z0 + .1), (.14, fondo, .16), MADERA(), bisel=.02, desorden=False, color=tono())


def entramado(p, ancho, fondo, z0, z1):
    """piso alto de revoque con vigas de madera (entramado): postes, soleras y riostras"""
    p.caja((0, 0, (z0 + z1) / 2), (ancho, fondo, z1 - z0), REVOQUE(), bisel=.03, desorden=False, color=(1, 1, 1))
    for y, cara in ((-fondo / 2, -1), (fondo / 2, 1)):
        for z in (z0 + .08, z1 - .08):
            p.caja((0, y + cara * .03, z), (ancho + .1, .14, .16), MADERA(), bisel=.02, desorden=False, color=tono())
        n = max(2, int(ancho / 1.3))
        for k in range(n + 1):
            x = -ancho / 2 + k * ancho / n
            p.caja((x, y + cara * .03, (z0 + z1) / 2), (.15, .14, z1 - z0), MADERA(), bisel=.02, desorden=False, color=tono())
            if k < n and k % 2 == 0:
                ang = math.atan2(z1 - z0, ancho / n)
                p.caja((x + ancho / n / 2, y + cara * .025, (z0 + z1) / 2), (math.hypot(ancho / n, z1 - z0) - .1, .12, .12), MADERA(),
                       bisel=.015, giro=(0, -ang, 0), desorden=False, color=tono())
    for x, cara in ((-ancho / 2, -1), (ancho / 2, 1)):
        for z in (z0 + .08, z1 - .08):
            p.caja((x + cara * .03, 0, z), (.14, fondo + .1, .16), MADERA(), bisel=.02, desorden=False, color=tono())
        for k in range(3):
            y = -fondo / 2 + k * fondo / 2
            p.caja((x + cara * .03, y, (z0 + z1) / 2), (.14, .15, z1 - z0), MADERA(), bisel=.02, desorden=False, color=tono())


# ---------------------------------------------------------------- piezas
def casa(nombre, ancho, fondo, ventanas_alto=2):
    """casa de dos plantas: planta baja de piedra con puerta, piso alto de entramado, tejado de teja y chimenea"""
    p = K.Pieza(nombre)
    alto_baja = 2.7
    puerta_x = -ancho * .18
    huecos = [(puerta_x - .75, puerta_x + .75, 0, 2.4), (ancho * .25 - .5, ancho * .25 + .5, .9, 2.0)]
    muros_casa(p, ancho, fondo, 0, alto_baja, PIEDRA(), huecos_frente=huecos, huecos_lado=[(-.5, .5, .9, 2.0)])
    puerta(p, puerta_x, -fondo / 2 + .12)
    ventana(p, ancho * .25, -fondo / 2 + .12, 1.45, .8, .9)
    for lado in (-1, 1):
        q = K.Pieza("tmp")
        ventana(q, 0, -.12, 1.45, .7, .8)
        bmesh.ops.rotate(q.bm, verts=list(q.bm.verts), cent=(0, 0, 0), matrix=Matrix.Rotation(math.radians(-90 * lado), 3, "Z"))
        bmesh.ops.translate(q.bm, vec=(lado * (ancho / 2 - .05), 0, 0), verts=list(q.bm.verts))
        _juntar(p, q)
    # piso alto, algo volado
    z1 = alto_baja + 2.3
    entramado(p, ancho + .3, fondo + .3, alto_baja, z1)
    for k in range(ventanas_alto):
        x = -ancho / 2 + (k + .5) * ancho / ventanas_alto
        ventana(p, x, -(fondo + .3) / 2 - .02, alto_baja + 1.2, .65, .8)
    # repisa bajo el piso alto (canes)
    for k in range(int(ancho / .7) + 1):
        x = -ancho / 2 + k * ancho / int(ancho / .7)
        p.caja((x, -fondo / 2 - .05, alto_baja - .1), (.14, .4, .14), MADERA(), bisel=.02, desorden=False, color=tono())
    tejado(p, ancho + .3, fondo + .3, z1, (fondo + .3) * .55)
    # chimenea
    cx, cy = ancho * .3, fondo * .15
    z = z1 + (fondo / 2 - abs(cy)) * .9
    for h in K.hiladas(1.9, .3, .4):
        p.caja((cx, cy, z + h / 2), (.7, .7, h - J), PIEDRA())
        z += h
    p.caja((cx, cy, z + .06), (.86, .86, .12), PIEDRA(), bisel=.03)
    return p.crear()


def torre(nombre):
    """torre cuadrada de la muralla: 4 × 4 m, 6 m de alto, con almenas y matacanes"""
    p = K.Pieza(nombre)
    lado, alto = 4.0, 6.2
    muros_casa(p, lado, lado, 0, alto, PIEDRA(), huecos_frente=[(-.25, .25, 3.3, 4.3)])
    p.caja((0, -lado / 2 + .1, 3.8), (.4, .1, 1.0), mat("junta", (.05, .045, .04), rugosidad=1), bisel=0, desorden=False, color=(1, 1, 1))
    # cornisa volada y almenas
    p.caja((0, 0, alto + .12), (lado + .5, lado + .5, .24), PIEDRA(), bisel=.05)
    for k in range(8):
        for s in range(4):
            t = -lado / 2 - .1 + (k + .5) * (lado + .2) / 8
            if k % 2:
                continue
            x, y = [(t, -lado / 2 - .1), (lado / 2 + .1, t), (-t, lado / 2 + .1), (-lado / 2 - .1, -t)][s]
            p.caja((x, y, alto + .24 + .35), (.5, .5, .7), PIEDRA())
    for k in range(5):
        x = -lado / 2 + (k + .5) * lado / 5
        p.caja((x, -lado / 2 - .1, alto - .15), (.22, .3, .3), PIEDRA(), bisel=.03)
    # estandarte rojo de Inca
    p.cilindro((0, 0, alto + 1.4), .05, 2.4, MADERA(), segmentos=8)
    prisma(p, [(0, alto + 2.5), (1.2, alto + 2.3), (0, alto + 2.0)], -.02, .02, mat("tela_roja", (.6, .06, .04)))
    return p.crear()


def almenas(nombre):
    """remate de la muralla para una casilla: parapeto con dos almenas (a lo largo de X)"""
    p = K.Pieza(nombre)
    p.caja((0, 0, .12), (2.0, 1.4, .24), PIEDRA(), bisel=.04)
    for x in (-.5, .5):
        p.caja((x, -.45, .24 + .32), (.55, .45, .64), PIEDRA())
    return p.crear()


def fuente(nombre):
    """fuente de la plaza: pilón redondo de piedra (r 2,6 m), agua, columna y taza alta"""
    p = K.Pieza(nombre)
    agua = mat("agua", (.08, .2, .25))
    n = 20
    r0, r1 = 2.2, 2.75
    for k in range(n):
        a = 2 * math.pi * k / n
        rm = (r0 + r1) / 2
        lg = 2 * math.pi * rm / n
        for z, h in ((.2, .4), (.55, .3)):
            p.caja((math.cos(a) * rm, math.sin(a) * rm, z), (r1 - r0 - .02, lg - J, h - J), PIEDRA(), giro=(0, 0, a))
    p.cilindro((0, 0, .1), r0 + .05, .2, PIEDRA(), segmentos=24)
    p.cilindro((0, 0, .52), r0 + .02, .04, agua, segmentos=24)
    # escalón alrededor
    p.cilindro((0, 0, .05), r1 + .35, .1, PIEDRA(), segmentos=28, color=(.85, .85, .85))
    # columna central y tazas
    z = .2
    for h in (.45, .45, .45):
        p.cilindro((0, 0, z + h / 2), .38, h - J, PIEDRA(), segmentos=12)
        z += h
    p.cilindro((0, 0, z + .15), .45, .3, PIEDRA(), segmentos=16, radio2=1.2)
    p.cilindro((0, 0, z + .28), 1.1, .04, agua, segmentos=20)
    p.cilindro((0, 0, z + .7), .2, .8, PIEDRA(), segmentos=10)
    p.cilindro((0, 0, z + 1.15), .22, .2, PIEDRA(), segmentos=10, radio2=.5)
    p.cilindro((0, 0, z + 1.27), .45, .03, agua, segmentos=16)
    p.cilindro((0, 0, z + 1.5), .1, .3, mat("oro", (0.85, 0.6, 0.2), rugosidad=.35, metal=.9), segmentos=8, radio2=.02)
    return p.crear()


def puesto(nombre, tela):
    """puesto de mercado de 2 × 2 m: mostrador, cuatro postes y toldo a rayas"""
    p = K.Pieza(nombre)
    t1 = mat(tela, (.6, .06, .04) if tela == "tela_roja" else (.08, .18, .5))
    t2 = mat("tela_clara", (.85, .8, .68))
    p.caja((0, -.3, .45), (1.7, .7, .9), MADERA(), bisel=.03, color=tono())
    p.caja((0, -.3, .92), (1.85, .8, .06), MADERA(), bisel=.02, color=(.8, .8, .8))
    for x in (-.85, .85):
        for y in (-.75, .75):
            alto = 2.2 if y < 0 else 2.6
            p.caja((x, y, alto / 2), (.1, .1, alto), MADERA(), bisel=.02, desorden=False, color=tono())
    ang = math.atan2(.4, 1.6)
    for k in range(6):
        x = -.95 + (k + .5) * 1.9 / 6
        p.caja((x, 0, 2.42), (1.9 / 6, 1.75, .04), t1 if k % 2 == 0 else t2, bisel=.0, giro=(-ang, 0, 0), desorden=False, color=(1, 1, 1))
    # festón del toldo
    for k in range(6):
        x = -.95 + (k + .5) * 1.9 / 6
        p.caja((x, -.86, 2.12), (1.9 / 6, .03, .2), t1 if k % 2 == 0 else t2, bisel=0, desorden=False, color=(1, 1, 1))
    # mercancía: cestas y sacos
    for x in (-.5, 0, .5):
        p.cilindro((x, -.3, 1.02), .18, .14, mat("mimbre", (.55, .4, .2)), segmentos=10, radio2=.22)
    for x in (-.55, .55):
        p.cilindro((x, .3, .3), .3, .6, t2, segmentos=10, radio2=.18)
    return p.crear()


def farol(nombre):
    """farola de hierro de 3 m con farol de luz cálida (Godot pone la luz a 2,8 m)"""
    p = K.Pieza(nombre)
    p.caja((0, 0, .15), (.5, .5, .3), PIEDRA(), bisel=.04)
    p.cilindro((0, 0, 1.55), .06, 2.5, HIERRO(), segmentos=8)
    p.caja((0, 0, 2.6), (.42, .42, .06), HIERRO(), bisel=.01, desorden=False)
    p.caja((0, 0, 2.82), (.3, .3, .38), VENTANA(), bisel=.01, desorden=False, color=(1, 1, 1))
    for x in (-.15, .15):
        for y in (-.15, .15):
            p.caja((x, y, 2.82), (.04, .04, .42), HIERRO(), bisel=0, desorden=False)
    p.cilindro((0, 0, 3.1), .26, .2, HIERRO(), segmentos=8, radio2=.04)
    return p.crear()


def arbol(nombre):
    """árbol sencillo: tronco y copa de bolas de hojas"""
    p = K.Pieza(nombre)
    corteza = mat("corteza", (.25, .17, .1))
    hoja = mat("hoja", (.16, .3, .1))
    p.cilindro((0, 0, 1.2), .22, 2.4, corteza, segmentos=8, radio2=.14)
    for k in range(7):
        a = k * 2.4
        r = 0 if k == 0 else .9
        tmp = bmesh.new()
        bmesh.ops.create_icosphere(tmp, subdivisions=1, radius=R.uniform(.9, 1.3))
        bmesh.ops.translate(tmp, vec=(math.cos(a) * r, math.sin(a) * r, 2.9 + R.uniform(-.3, .6) + (.5 if k == 0 else 0)), verts=tmp.verts)
        c = 1 + R.uniform(-.2, .2)
        p._copiar(tmp, (c, c, c), hoja)
    return p.crear()


def portal_mazmorra(nombre):
    """entrada a la mazmorra en la muralla: 3 casillas (6 m) de ancho, arco con runas y escalera que baja al norte"""
    p = K.Pieza(nombre)
    runa = mat("runa", (.3, .05, .02), emision=(1.0, .3, .08))
    hueco = 2.6
    alto = 4.6
    # machones
    for lado in (-1, 1):
        cx = lado * (hueco / 2 + .95)
        z = 0
        for h in K.hiladas(alto, .36, .5):
            p.caja((cx, 0, z + h / 2), (1.9 - J, 2.0 - J, h - J), PIEDRA())
            z += h
        p.caja((cx, -.1, alto + .2), (2.1, 2.2, .4), PIEDRA(), bisel=.05)
        # pebetero encima del machón
        p.cilindro((cx, -.1, alto + .55), .35, .3, HIERRO(), segmentos=12, radio2=.5)
        p.cilindro((cx, -.1, alto + .72), .42, .05, mat("brasa", (0.1, 0.02, 0.0), rugosidad=1, emision=(1.0, 0.35, 0.08)), segmentos=12)
    # arco de dovelas con runas
    r0 = hueco / 2
    r1 = r0 + .55
    arr = 2.6
    nd = 11
    for k in range(nd):
        a = math.pi * (k + .5) / nd
        rm = (r0 + r1) / 2
        for y in (-.7, 0, .7):
            p.caja((math.cos(a) * rm, y, arr + math.sin(a) * rm), (math.pi * rm / nd - J, .66, r1 - r0), PIEDRA(), giro=(0, -(a - math.pi / 2), 0))
        if k % 2 == 0:
            p.caja((math.cos(a) * rm, -1.05, arr + math.sin(a) * rm), (.18, .04, .22), runa, bisel=0, giro=(0, -(a - math.pi / 2), 0), desorden=False, color=(1, 1, 1))
    for lado in (-1, 1):
        p.caja((lado * (r0 - .05), 0, arr / 2), (.25, 2.0, arr), PIEDRA(), bisel=.04)
    # tímpano macizo entre el arco y el remate
    p.caja((0, 0, alto - .25), (hueco + .1, 2.0, .9), PIEDRA(), bisel=.04)
    for lado in (-1, 1):
        p.caja((lado * 1.0, 0, arr + 1.0), (.7, 2.0, 1.2), PIEDRA(), bisel=.04)
    # paso oscuro: paredes y bóveda por dentro del hueco (para que se lea como un túnel que baja)
    sombra = mat("sombra", (.05, .045, .04), rugosidad=1)
    for lado in (-1, 1):
        p.caja((lado * (r0 - .2), .3, (arr - 2.0) / 2), (.04, 2.2, arr + 2.0), sombra, bisel=0, desorden=False, color=(1, 1, 1))
    p.caja((0, .3, arr + .2), (hueco - .2, 2.2, .04), sombra, bisel=0, desorden=False, color=(1, 1, 1))
    # escalera que baja hacia el norte (+Y de Blender) y fondo negro
    for k in range(7):
        z = -k * .22
        p.caja((0, -.55 + k * .26, z - .11), (hueco - .1, .3, .22), PIEDRA(), bisel=.02, desorden=False, color=tono(.08))
    p.caja((0, 1.2, -.5), (hueco + .2, .3, 6), mat("negro", (0.0, 0.0, 0.0), rugosidad=1), bisel=0, desorden=False, color=(1, 1, 1))
    p.caja((0, .4, -1.9), (hueco + .2, 2.0, .2), mat("negro", (0.0, 0.0, 0.0), rugosidad=1), bisel=0, desorden=False, color=(1, 1, 1))
    # losa de umbral grabada con la runa
    p.caja((0, -1.1, .02), (hueco, .5, .06), PIEDRA(), bisel=.02, desorden=False)
    p.caja((0, -1.1, .055), (.5, .2, .02), runa, bisel=0, desorden=False, color=(1, 1, 1))
    return p.crear()


def puerta_ciudad(nombre):
    """puerta grande de la muralla (cerrada): 3 casillas de ancho, arco y dos hojas de madera con herrajes"""
    p = K.Pieza(nombre)
    hueco = 3.0
    alto = 5.2
    for lado in (-1, 1):
        cx = lado * (hueco / 2 + .75)
        z = 0
        for h in K.hiladas(alto, .36, .5):
            p.caja((cx, 0, z + h / 2), (1.5 - J, 2.0 - J, h - J), PIEDRA())
            z += h
    p.caja((0, 0, alto - .5), (hueco + .2, 2.0, 1.0), PIEDRA(), bisel=.05)
    r0 = hueco / 2
    for k in range(9):
        a = math.pi * (k + .5) / 9
        p.caja((math.cos(a) * (r0 + .2), -.85, 2.9 + math.sin(a) * (r0 + .2)), (.5, .3, .4), PIEDRA(), giro=(0, -(a - math.pi / 2), 0))
    p.caja((0, 0, alto + .2), (hueco + 3.2, 2.2, .4), PIEDRA(), bisel=.05)
    for x in range(-2, 3):
        p.caja((x * 1.2, -.6, alto + .7), (.55, .5, .6), PIEDRA())
    # hojas de madera bajo el arco
    tabla = .3
    for k in range(int(hueco / tabla)):
        x = -hueco / 2 + (k + .5) * tabla
        h = 2.9 + math.sqrt(max(0, r0 * r0 - x * x)) - .05
        p.caja((x, -.55, h / 2), (tabla - .02, .16, h), MADERA(), bisel=.02, desorden=False, color=tono(.15))
    for z in (.7, 2.0, 3.3):
        p.caja((0, -.66, z), (hueco - .1, .04, .14), HIERRO(), bisel=.01, desorden=False)
    for x in (-.5, .5):
        p.cilindro((x, -.68, 1.6), .12, .04, HIERRO(), segmentos=10)
    p.caja((0, -.64, 1.9), (.04, .05, 3.8), HIERRO(), bisel=0, desorden=False)
    return p.crear()


def forja(nombre):
    """forja del herrero: horno de piedra con brasas, yunque y barril de agua"""
    p = K.Pieza(nombre)
    for h, z in ((.5, .25), (.45, .72)):
        p.caja((-.4, .2, z), (1.1, 1.0, h - J), PIEDRA())
    p.caja((-.4, .2, 1.0), (1.2, 1.1, .1), PIEDRA(), bisel=.02)
    p.caja((-.4, -.1, .8), (.7, .45, .25), mat("brasa", (0.1, 0.02, 0.0), rugosidad=1, emision=(1.0, 0.35, 0.08)), bisel=0, desorden=False, color=(1, 1, 1))
    p.cilindro((-.4, .35, 1.7), .25, 1.3, PIEDRA(), segmentos=8, radio2=.18)
    # yunque
    p.caja((.55, -.2, .25), (.35, .35, .5), MADERA(), bisel=.03, color=tono())
    p.caja((.55, -.2, .58), (.55, .22, .16), HIERRO(), bisel=.02, desorden=False)
    p.cilindro((.88, -.2, .6), .07, .1, HIERRO(), segmentos=8, radio2=.01)
    p.caja((.62, -.15, .7), (.3, .05, .05), HIERRO(), bisel=0, desorden=False)
    return p.crear()


def mesa_alquimia(nombre):
    """mesa del alquimista: tablero, frascos de colores que brillan y un caldero"""
    p = K.Pieza(nombre)
    p.caja((0, 0, .82), (1.6, .8, .08), MADERA(), bisel=.02, color=tono())
    for x in (-.7, .7):
        for y in (-.3, .3):
            p.caja((x, y, .4), (.08, .08, .8), MADERA(), bisel=.01, desorden=False, color=tono())
    colores = [("vidrio_rojo", (.9, .1, .1)), ("vidrio_azul", (.15, .3, 1.0)), ("vidrio_verde", (.2, .9, .3)), ("vidrio_rojo", (.9, .1, .1))]
    for k, (n, c) in enumerate(colores):
        x = -.55 + k * .36
        m = mat(n, tuple(v * .3 for v in c), emision=c)
        p.cilindro((x, -.05, .98), .09, .22, m, segmentos=10)
        p.cilindro((x, -.05, 1.14), .03, .1, m, segmentos=6)
    p.cilindro((.6, .55, .3), .35, .55, HIERRO(), segmentos=14, radio2=.28)
    p.cilindro((.6, .55, .56), .3, .02, mat("vidrio_verde", (.06, .27, .09), emision=(.2, .9, .3)), segmentos=14)
    return p.crear()


def altar_runas(nombre):
    """mesa del runista: pedestal de piedra con piedras rúnicas que brillan"""
    p = K.Pieza(nombre)
    runa = mat("runa_azul", (.05, .1, .3), emision=(.3, .55, 1.0))
    p.caja((0, 0, .1), (1.2, .9, .2), PIEDRA(), bisel=.03)
    p.caja((0, 0, .5), (.9, .6, .6), PIEDRA())
    p.caja((0, 0, .85), (1.3, .9, .1), PIEDRA(), bisel=.03)
    for k in range(3):
        x = -.4 + k * .4
        p.caja((x, 0, 1.0), (.22, .1, .28), PIEDRA(), bisel=.03, color=(.7, .7, .7))
        p.caja((x, -.055, 1.0), (.1, .02, .16), runa, bisel=0, desorden=False, color=(1, 1, 1))
    p.caja((0, -.31, .55), (.4, .02, .3), runa, bisel=0, desorden=False, color=(1, 1, 1))
    return p.crear()


def cofre_almacen(nombre):
    """arcón grande del almacén, con herrajes"""
    p = K.Pieza(nombre)
    p.caja((0, 0, .35), (1.5, .85, .7), MADERA(), bisel=.03, color=tono())
    p.caja((0, 0, .8), (1.52, .87, .22), MADERA(), bisel=.08, desorden=False, color=(.85, .85, .85))
    for x in (-.6, 0, .6):
        p.caja((x, 0, .55), (.08, .9, 1.0), HIERRO(), bisel=.01, desorden=False)
    p.caja((0, -.44, .62), (.2, .04, .22), mat("oro", (0.85, 0.6, 0.2), rugosidad=.35, metal=.9), bisel=.01, desorden=False)
    return p.crear()


def letrero(nombre):
    """letrero colgado de una barra (el texto lo pone Godot): tablón de 1 × 0,5 m a 2,6 m"""
    p = K.Pieza(nombre)
    p.cilindro((0, 0, 1.6), .06, 3.2, MADERA(), segmentos=8)
    p.caja((.5, 0, 3.05), (1.1, .08, .08), MADERA(), bisel=.01, desorden=False, color=tono())
    for x in (.2, .8):
        p.caja((x, 0, 2.95), (.02, .02, .2), HIERRO(), bisel=0, desorden=False)
    p.caja((.5, 0, 2.6), (1.0, .06, .5), MADERA(), bisel=.02, desorden=False, color=(.8, .8, .8))
    return p.crear()


def adoquines(nombre):
    """adoquines de una casilla (2 × 2 m) sobre una base oscura"""
    p = K.Pieza(nombre)
    ado = mat("adoquin", (.45, .42, .38))
    p.caja((0, 0, -.06), (2.0, 2.0, .08), mat("junta", (.08, .07, .06), rugosidad=1), bisel=0, color=(1, 1, 1), desorden=False)
    n = 5
    for j in range(n):
        x = -1.0 - (.2 if j % 2 else 0)
        while x < 1.0:
            lg = R.uniform(.32, .46)
            xa, xb = max(x, -1.0), min(x + lg, 1.0)
            x += lg
            if xb - xa < .1:
                continue
            y = -1.0 + (j + .5) * 2.0 / n
            p.caja(((xa + xb) / 2, y, -.03), (xb - xa - .04, 2.0 / n - .04, .07), ado, bisel=.03,
                   giro=(0, 0, 0), desorden=True)
    return p.crear()


def banco(nombre):
    p = K.Pieza(nombre)
    for x in (-.6, .6):
        p.caja((x, 0, .2), (.3, .4, .4), PIEDRA())
    p.caja((0, 0, .46), (1.7, .5, .12), PIEDRA(), bisel=.03)
    return p.crear()


def main(salida):
    K.limpiar()
    casa("casa_a", 6.0, 4.0, 2)
    casa("casa_b", 8.0, 6.0, 3)
    torre("torre")
    almenas("almenas")
    fuente("fuente")
    puesto("puesto_rojo", "tela_roja")
    puesto("puesto_azul", "tela_azul")
    farol("farol")
    arbol("arbol")
    portal_mazmorra("portal_mazmorra")
    puerta_ciudad("puerta_ciudad")
    forja("forja")
    mesa_alquimia("mesa_alquimia")
    altar_runas("altar_runas")
    cofre_almacen("cofre_almacen")
    letrero("letrero")
    adoquines("adoquines")
    adoquines("adoquines_b")
    banco("banco")
    for i, o in enumerate(bpy.data.objects):
        o.location.x = (i % 5) * 10
        o.location.y = (i // 5) * 10
    bpy.ops.export_scene.gltf(filepath=salida, export_format="GLB", export_apply=True,
                              export_vertex_color="ACTIVE", export_all_vertex_colors=False)
    print("kit de la ciudad exportado:", salida, len(bpy.data.objects), "piezas")


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    main(args[0] if args else "assets/kit/kit_ciudad.glb")
