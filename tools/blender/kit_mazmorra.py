"""Kit de arquitectura de la mazmorra, generado por código en Blender.

Uso:  python3 tools/blender/kit_mazmorra.py  [salida.glb]
      (con el módulo bpy: pip install bpy)  o  blender -b -P tools/blender/kit_mazmorra.py -- [salida.glb]

Cada pieza es un objeto con el nombre que espera Godot (KitMazmorra.PIEZAS). Medidas en metros:
una casilla mide 2 × 2, el suelo está en z = 0 y la pieza está centrada en el origen.
Blender usa Z hacia arriba; el exportador glTF lo pasa a Y hacia arriba (Blender -Y = Godot +Z = sur).

El estilo sale de los parámetros de abajo: tamaño de bloque, irregularidad, bisel, variación de color.
Cambia un número y vuelve a ejecutar: todas las piezas cambian igual.
"""
import math
import random
import sys

import bpy  # antes que bmesh: con el módulo bpy de pip, bmesh se carga al importar bpy
import bmesh
from mathutils import Matrix, Vector

CELDA = 2.0
ALTO_MURO = 3.0
BLOQUE = 0.5            # lado de los bloques de piedra
JUNTA = 0.035           # separación entre bloques
BISEL = 0.06            # redondeo de las aristas
DESORDEN = 0.025        # cuánto se mueve cada bloque de su sitio
GIRO = 2.5              # grados de giro al azar de cada bloque
TONO = 0.22             # variación de color entre bloques (0 = todos iguales)
SEMILLA = 7

R = random.Random(SEMILLA)


# ---------------------------------------------------------------- utilidades
def limpiar():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for m in list(bpy.data.meshes):
        bpy.data.meshes.remove(m)


_mats = {}


def material(nombre, color, rugosidad=0.85, metal=0.0, emision=None):
    if nombre in _mats:
        return _mats[nombre]
    m = bpy.data.materials.new(nombre)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Roughness"].default_value = rugosidad
    bsdf.inputs["Metallic"].default_value = metal
    if emision:
        bsdf.inputs["Emission Color"].default_value = (*emision, 1)
        bsdf.inputs["Emission Strength"].default_value = 4.0
    _mats[nombre] = m
    return m


class Pieza:
    """Acumula cajas biseladas (y otras formas) en un solo bmesh, con color por bloque y material."""

    def __init__(self, nombre):
        self.nombre = nombre
        self.bm = bmesh.new()
        self.col = self.bm.loops.layers.color.new("Col")
        self.mats = []

    def _mat(self, m):
        if m not in self.mats:
            self.mats.append(m)
        return self.mats.index(m)

    def _pintar(self, caras, color, mat):
        idx = self._mat(mat)
        for f in caras:
            f.material_index = idx
            for l in f.loops:
                l[self.col] = (*color, 1.0)

    def caja(self, centro, tam, mat, bisel=BISEL, color=None, giro=(0, 0, 0), desorden=True):
        """caja biselada de tamaño tam centrada en centro; con desorden se mueve y gira un poco"""
        tmp = bmesh.new()
        bmesh.ops.create_cube(tmp, size=1.0)
        bmesh.ops.scale(tmp, vec=Vector(tam), verts=tmp.verts)
        b = min(bisel, min(tam) * 0.3)
        if b > 0.001:
            bmesh.ops.bevel(tmp, geom=list(tmp.edges), offset=b, segments=2, profile=0.6, affect="EDGES")
        gx, gy, gz = giro
        if desorden:
            gx += math.radians(R.uniform(-GIRO, GIRO) * 0.4)
            gy += math.radians(R.uniform(-GIRO, GIRO) * 0.4)
            gz += math.radians(R.uniform(-GIRO, GIRO))
            centro = Vector(centro) + Vector((R.uniform(-1, 1) * DESORDEN, R.uniform(-1, 1) * DESORDEN, R.uniform(-.5, .5) * DESORDEN))
        rot = Matrix.Rotation(gz, 4, "Z") @ Matrix.Rotation(gy, 4, "Y") @ Matrix.Rotation(gx, 4, "X")
        bmesh.ops.transform(tmp, matrix=Matrix.Translation(Vector(centro)) @ rot, verts=tmp.verts)
        if color is None:
            v = 1.0 + R.uniform(-TONO, TONO)
            calido = R.uniform(-0.04, 0.04)
            color = (v * (1 + calido), v, v * (1 - calido))
        self._copiar(tmp, color, mat)

    def cilindro(self, centro, radio, alto, mat, segmentos=16, color=(1, 1, 1), radio2=None):
        tmp = bmesh.new()
        bmesh.ops.create_cone(tmp, cap_ends=True, segments=segmentos, radius1=radio, radius2=radio if radio2 is None else radio2, depth=alto)
        bmesh.ops.translate(tmp, vec=Vector(centro), verts=tmp.verts)
        self._copiar(tmp, color, mat)

    def _copiar(self, tmp, color, mat):
        tmp.normal_update()
        me = bpy.data.meshes.new("tmp")
        tmp.to_mesh(me)
        tmp.free()
        antes = set(self.bm.faces)
        self.bm.from_mesh(me)
        bpy.data.meshes.remove(me)
        nuevas = [f for f in self.bm.faces if f not in antes]
        self._pintar(nuevas, color, mat)

    def crear(self):
        me = bpy.data.meshes.new(self.nombre)
        self.bm.normal_update()
        self.bm.to_mesh(me)
        self.bm.free()
        for m in self.mats:
            me.materials.append(m)
        for p in me.polygons:
            p.use_smooth = True
        o = bpy.data.objects.new(self.nombre, me)
        bpy.context.collection.objects.link(o)
        return o


def hiladas(alto, minimo=0.36, maximo=0.5):
    """alturas de las hiladas de bloques que suman alto"""
    hs = []
    z = 0.0
    while alto - z > maximo:
        h = R.uniform(minimo, maximo)
        hs.append(h)
        z += h
    hs.append(alto - z)
    return hs


# ---------------------------------------------------------------- piezas
def muro(nombre, alto=ALTO_MURO):
    """bloque de muro de una casilla: bloques de piedra en el borde y una tapa de bloques arriba"""
    p = Pieza(nombre)
    piedra = material("piedra", (0.42, 0.37, 0.33))
    n = int(round(CELDA / BLOQUE))
    z = 0.0
    hs = hiladas(alto - 0.4)
    for k, h in enumerate(hs):
        borde = [(i, j) for i in range(n) for j in range(n) if i in (0, n - 1) or j in (0, n - 1)]
        usado = set()
        for (i, j) in borde:
            if (i, j) in usado:
                continue
            # a veces se juntan dos bloques en uno largo (aparejo)
            largo = 1
            vecino = (i + 1, j) if j in (0, n - 1) else (i, j + 1)
            if (k + i + j) % 2 == 0 and vecino in borde and vecino not in usado and R.random() < .55:
                largo = 2
            usado.add((i, j))
            if largo == 2:
                usado.add(vecino)
            cx = (i + (vecino[0] - i) * (largo - 1) / 2 + .5) * BLOQUE - CELDA / 2
            cy = (j + (vecino[1] - j) * (largo - 1) / 2 + .5) * BLOQUE - CELDA / 2
            sx = BLOQUE * (1 + (vecino[0] - i) * (largo - 1)) - JUNTA
            sy = BLOQUE * (1 + (vecino[1] - j) * (largo - 1)) - JUNTA
            p.caja((cx, cy, z + h / 2), (sx, sy, h - JUNTA), piedra)
        z += h
    # relleno interior (no se ve, tapa los huecos)
    p.caja((0, 0, z / 2), (CELDA - BLOQUE * 1.2, CELDA - BLOQUE * 1.2, z), piedra, bisel=0, color=(.25, .22, .2), desorden=False)
    # tapa: bloques algo desiguales
    for i in range(n):
        for j in range(n):
            h = R.uniform(.34, .44)
            p.caja(((i + .5) * BLOQUE - CELDA / 2, (j + .5) * BLOQUE - CELDA / 2, z + h / 2), (BLOQUE - JUNTA, BLOQUE - JUNTA, h), piedra)
    return p.crear()


def suelo(nombre, losas):
    """losas sobre una base oscura (la junta). losas: lista de (x0, y0, x1, y1) en metros desde la esquina"""
    p = Pieza(nombre)
    losa = material("losa", (0.40, 0.34, 0.29))
    junta = material("junta", (0.08, 0.07, 0.06), rugosidad=1)
    p.caja((0, 0, -0.07), (CELDA, CELDA, 0.1), junta, bisel=0, color=(1, 1, 1), desorden=False)
    for (x0, y0, x1, y1) in losas:
        cx = (x0 + x1) / 2 - CELDA / 2
        cy = (y0 + y1) / 2 - CELDA / 2
        e = R.uniform(.08, .11)
        p.caja((cx, cy, -e / 2 + R.uniform(-.008, .008)), (x1 - x0 - .05, y1 - y0 - .05, e), losa, bisel=.035,
               giro=(math.radians(R.uniform(-.8, .8)), math.radians(R.uniform(-.8, .8)), 0))
    return p.crear()


def pilar(nombre):
    p = Pieza(nombre)
    piedra = material("piedra", (0.42, 0.37, 0.33))
    p.caja((0, 0, .15), (1.1, 1.1, .3), piedra)
    z = .3
    for h in hiladas(ALTO_MURO - .6, .3, .42):
        p.caja((0, 0, z + h / 2), (.8, .8, h - JUNTA), piedra, giro=(0, 0, math.radians(R.uniform(-4, 4))))
        z += h
    p.caja((0, 0, z + .15), (1.1, 1.1, .3), piedra)
    return p.crear()


def arco(nombre):
    """casilla de muro con un paso abovedado de norte a sur (a lo largo de Y)"""
    p = Pieza(nombre)
    piedra = material("piedra", (0.42, 0.37, 0.33))
    hueco = 1.2
    jamba = (CELDA - hueco) / 2
    arranque = 1.45
    # jambas: columnas de bloques a los lados
    for lado in (-1, 1):
        cx = lado * (hueco / 2 + jamba / 2)
        z = 0.0
        for h in hiladas(ALTO_MURO - .4, .34, .46):
            for j in range(4):
                p.caja((cx, (j + .5) * BLOQUE - CELDA / 2, z + h / 2), (jamba - JUNTA, BLOQUE - JUNTA, h - JUNTA), piedra)
            z += h
    # dovelas: bloques en abanico que hacen el arco (en las dos caras y por dentro)
    r0 = hueco / 2
    r1 = r0 + .38
    nd = 9
    for k in range(nd):
        a = math.pi * (k + .5) / nd
        rm = (r0 + r1) / 2
        cx = math.cos(a) * rm
        cz = arranque + math.sin(a) * rm
        largo = math.pi * rm / nd - JUNTA
        for j in range(4):
            p.caja((cx, (j + .5) * BLOQUE - CELDA / 2, cz), (largo, BLOQUE - JUNTA, r1 - r0), piedra,
                   giro=(0, -(a - math.pi / 2), 0))
    # relleno entre el arco y la tapa
    z_top = ALTO_MURO - .4
    for lado in (-1, 1):
        p.caja((lado * .55, 0, (arranque + .55 + z_top) / 2 + .05), (.5, CELDA - .1, z_top - arranque - .45), piedra, bisel=.03)
    p.caja((0, 0, z_top - .08), (hueco * .7, CELDA - .1, .3), piedra, bisel=.03)
    # tapa
    n = 4
    for i in range(n):
        for j in range(n):
            h = R.uniform(.34, .44)
            p.caja(((i + .5) * BLOQUE - CELDA / 2, (j + .5) * BLOQUE - CELDA / 2, z_top + h / 2), (BLOQUE - JUNTA, BLOQUE - JUNTA, h), piedra)
    return p.crear()


def antorcha(nombre):
    """soporte de pared: el origen está en la cara del muro, la antorcha sale hacia -Y (sur en Godot)"""
    p = Pieza(nombre)
    hierro = material("hierro", (0.12, 0.11, 0.1), rugosidad=.5, metal=.8)
    madera = material("madera", (0.30, 0.18, 0.09))
    p.caja((0, -.03, 0), (.16, .06, .28), hierro, bisel=.01, desorden=False, color=(1, 1, 1))
    p.caja((0, -.14, .02), (.04, .2, .04), hierro, bisel=.005, desorden=False, color=(1, 1, 1))
    tmp_giro = (math.radians(-25), 0, 0)
    p.caja((0, -.24, .14), (.06, .06, .42), madera, bisel=.01, giro=tmp_giro, desorden=False, color=(1, 1, 1))
    p.cilindro((0, -.3, .36), .07, .12, hierro, segmentos=10, radio2=.1)
    return p.crear()


def brasero(nombre):
    """pedestal de piedra con cuenco de hierro y brasas (el fuego lo pone Godot encima, a 1,1 m)"""
    p = Pieza(nombre)
    piedra = material("piedra", (0.42, 0.37, 0.33))
    hierro = material("hierro", (0.12, 0.11, 0.1), rugosidad=.5, metal=.8)
    brasa = material("brasa", (0.1, 0.02, 0.0), rugosidad=1, emision=(1.0, 0.35, 0.08))
    p.caja((0, 0, .1), (.95, .95, .2), piedra)
    z = .2
    for h in (.3, .28):
        for i in range(2):
            for j in range(2):
                p.caja(((i - .5) * .38, (j - .5) * .38, z + h / 2), (.37, .37, h - JUNTA), piedra)
        z += h
    p.caja((0, 0, z + .08), (.9, .9, .16), piedra)
    z += .16
    p.cilindro((0, 0, z + .1), .3, .2, hierro, segmentos=20, radio2=.42)
    p.cilindro((0, 0, z + .17), .36, .04, brasa, segmentos=20)
    return p.crear()


def estandarte(nombre):
    """estandarte colgado de la pared (origen en la cara del muro, a la altura de la barra)"""
    p = Pieza(nombre)
    hierro = material("hierro", (0.12, 0.11, 0.1), rugosidad=.5, metal=.8)
    tela = material("tela", (0.45, 0.04, 0.03), rugosidad=.9)
    oro = material("oro", (0.85, 0.6, 0.2), rugosidad=.35, metal=.9)
    p.cilindro((0, -.08, 0), .025, .8, hierro, segmentos=8)
    bm = p.bm
    me = bpy.data.meshes.new("t")
    # la barra va a lo largo de X: giramos el cilindro
    bmesh.ops.rotate(bm, verts=list(bm.verts), cent=(0, -.08, 0), matrix=Matrix.Rotation(math.radians(90), 3, "Y"))
    bpy.data.meshes.remove(me)
    # tela: pocas filas onduladas, con punta abajo
    filas, cols = 8, 6
    ancho, alto = .62, 1.3
    vs = []
    for r in range(filas + 1):
        fila = []
        for c in range(cols + 1):
            x = (c / cols - .5) * ancho
            t = r / filas
            z = -t * alto
            if r == filas:
                z -= (1 - abs(c / cols - .5) * 2) * .18
            y = -.1 - math.sin(c / cols * math.pi * 2 + t * 2) * .025 * t
            fila.append(bm.verts.new((x, y, z - .03)))
        vs.append(fila)
    idx = p._mat(tela)
    for r in range(filas):
        for c in range(cols):
            f = bm.faces.new((vs[r][c], vs[r][c + 1], vs[r + 1][c + 1], vs[r + 1][c]))
            f.material_index = idx
            for l in f.loops:
                l[p.col] = (1, 1, 1, 1)
    # emblema
    p.caja((0, -.13, -.55), (.22, .03, .22), oro, bisel=.01, giro=(0, math.radians(45), 0), desorden=False, color=(1, 1, 1))
    return p.crear()


def barril(nombre):
    p = Pieza(nombre)
    madera = material("madera", (0.30, 0.18, 0.09))
    hierro = material("hierro", (0.12, 0.11, 0.1), rugosidad=.5, metal=.8)
    p.cilindro((0, 0, .2), .3, .4, madera, radio2=.34)
    p.cilindro((0, 0, .6), .34, .4, madera, radio2=.3)
    for z in (.12, .4, .68):
        p.cilindro((0, 0, z), .345 if z == .4 else .33, .05, hierro)
    return p.crear()


def caja_madera(nombre):
    p = Pieza(nombre)
    madera = material("madera", (0.30, 0.18, 0.09))
    for k in range(4):
        p.caja((0, 0, .08 + k * .16), (.7, .7, .15), madera, bisel=.015)
    return p.crear()


# ---------------------------------------------------------------- muros con cara
# Un muro es un «núcleo» (bloque liso de la casilla con la tapa de piedras) y, en cada lado que da
# al suelo, una «cara» de sillería: zócalo, sillares rectangulares a matajunta, imposta y cornisa.
# Las caras miran a -Y (sur en Godot) y Godot las gira hacia el suelo. Variantes: lisa, columna,
# nicho, arco ciego, reja, rota y con hiedra. En las esquinas Godot pone una columna de esquina.
FRENTE = -CELDA / 2       # plano de la cara (borde sur de la casilla)
ZOCALO = 0.36
IMPOSTA = 2.5             # altura de la cornisa


def _en_hueco(huecos, x, z):
    for h in huecos:
        if h[0] == "rect" and h[1] <= x <= h[2] and h[3] <= z <= h[4]:
            return True
        if h[0] == "arco":   # rectángulo con medio punto arriba: (x0, x1, z0, z_arranque)
            x0, x1, z0, za = h[1:5]
            r = (x1 - x0) / 2
            cx = (x0 + x1) / 2
            if x0 <= x <= x1 and z0 <= z <= za:
                return True
            if z > za and (x - cx) ** 2 + (z - za) ** 2 <= r * r:
                return True
    return False


def sillares(p, mat, x0, x1, z0, z1, relieve=(0.03, 0.09), largo=(0.45, 0.95), alto=(0.28, 0.42), huecos=(), quitar=0.0, fondo=0.3):
    """fábrica de sillares rectangulares a matajunta delante del plano FRENTE, entre x0..x1 y z0..z1"""
    z = z0
    for h in hiladas(z1 - z0, *alto) if z1 - z0 > alto[1] else [z1 - z0]:
        x = x0 - R.uniform(0, largo[1] * .6)
        while x < x1:
            l = R.uniform(*largo)
            a, b = max(x, x0), min(x + l, x1)
            x += l
            if b - a < 0.12:
                continue
            cx, cz = (a + b) / 2, z + h / 2
            if huecos and (_en_hueco(huecos, cx, cz) or _en_hueco(huecos, a + .05, cz) or _en_hueco(huecos, b - .05, cz)):
                continue
            if quitar and R.random() < quitar:
                continue
            r = R.uniform(*relieve)
            p.caja((cx, FRENTE - r + fondo / 2, cz), (b - a - JUNTA, fondo, h - JUNTA), mat)
        z += h


def _fondo(p, color=(1, 1, 1)):
    """plano oscuro detrás de la sillería: se ve en las juntas y huecos"""
    junta = material("junta", (0.08, 0.07, 0.06), rugosidad=1)
    p.caja((0, FRENTE + .03, ALTO_MURO / 2), (CELDA, .06, ALTO_MURO), junta, bisel=0, color=color, desorden=False)


def _cornisa(p, piedra):
    # imposta saliente y última hilada de remate
    x = -CELDA / 2
    while x < CELDA / 2 - .1:
        l = min(R.uniform(.6, 1.0), CELDA / 2 - x)
        p.caja((x + l / 2, FRENTE - .1 + .2, IMPOSTA + .1), (l - JUNTA, .4, .2 - JUNTA), piedra, bisel=.04)
        x += l
    sillares(p, piedra, -CELDA / 2, CELDA / 2, IMPOSTA + .2, ALTO_MURO, relieve=(0.02, 0.06), alto=(.3, .3))


def _zocalo(p, piedra):
    x = -CELDA / 2
    while x < CELDA / 2 - .1:
        l = min(R.uniform(.55, 1.0), CELDA / 2 - x)
        p.caja((x + l / 2, FRENTE - .13 + .2, ZOCALO / 2), (l - JUNTA, .4, ZOCALO - JUNTA), piedra, bisel=.05)
        x += l


def cara(nombre, tipo="lisa"):
    p = Pieza(nombre)
    piedra = material("piedra", (0.42, 0.37, 0.33))
    hierro = material("hierro", (0.12, 0.11, 0.1), rugosidad=.5, metal=.8)
    oscuro = material("junta", (0.08, 0.07, 0.06), rugosidad=1)
    _fondo(p)
    huecos = []
    if tipo == "nicho":
        huecos = [("arco", -.48, .48, .75, 1.6)]
    elif tipo == "arco_ciego":
        huecos = [("arco", -.78, .78, ZOCALO, 1.55)]
    elif tipo == "puerta":   # puerta negra hasta el suelo (las de las salas secretas, SalaSecreta)
        huecos = [("arco", -.55, .55, 0, 1.45)]
    elif tipo == "reja":
        huecos = [("rect", -.45, .45, 1.15, 2.15)]
    elif tipo == "columna":
        huecos = [("rect", -.36, .36, 0, ALTO_MURO)]
    _zocalo(p, piedra) if tipo not in ("arco_ciego", "puerta") else None
    sillares(p, piedra, -CELDA / 2, CELDA / 2, ZOCALO, IMPOSTA, huecos=huecos, quitar=.22 if tipo == "rota" else 0.0)
    _cornisa(p, piedra)
    if tipo in ("nicho", "arco_ciego", "puerta"):
        x0, x1, z0, za = huecos[0][1:5]
        r = (x1 - x0) / 2
        # fondo del hueco, metido hacia dentro, y dovelas alrededor
        if tipo == "arco_ciego":
            sillares(p, piedra, x0, x1, 0, za + r, relieve=(-.2, -.16), largo=(.4, .7), alto=(.3, .4))
            for lado in (-1, 1):   # jambas del arco
                for k, (za_, zb_) in enumerate([(0, .5), (.5, 1.0), (1.0, za)]):
                    p.caja((lado * (r + .1), FRENTE - .06 + .15, (za_ + zb_) / 2), (.22, .3, zb_ - za_ - JUNTA), piedra, bisel=.04)
        elif tipo == "puerta":
            p.caja((0, FRENTE + .32, (z0 + za + r) / 2), (x1 - x0, .1, za + r - z0), oscuro, bisel=0, desorden=False, color=(1, 1, 1))
            for lado in (-1, 1):   # jambas
                p.caja((lado * (r + .1), FRENTE - .06 + .15, za / 2), (.22, .3, za - JUNTA), piedra, bisel=.04)
            p.caja((0, FRENTE - .05, .03), (x1 - x0 + .2, .5, .06), piedra, bisel=.02)   # umbral
        else:
            p.caja((0, FRENTE + .28, (z0 + za + r) / 2), (x1 - x0, .1, za + r - z0), oscuro, bisel=0, desorden=False, color=(1, 1, 1))
            p.caja((0, FRENTE - .1 + .2, z0 - .06), (x1 - x0 + .3, .4, .12), piedra, bisel=.03)   # repisa
        nd = 9 if tipo == "arco_ciego" else (8 if tipo == "puerta" else 7)
        for k in range(nd):
            a = math.pi * (k + .5) / nd
            rm = r + .12
            p.caja((math.cos(a) * rm, FRENTE - .08 + .15, za + math.sin(a) * rm), (math.pi * rm / nd - JUNTA, .3, .24), piedra,
                   giro=(0, -(a - math.pi / 2), 0))
    if tipo == "reja":
        x0, x1, z0, z1 = huecos[0][1:5]
        p.caja((0, FRENTE + .3, (z0 + z1) / 2), (x1 - x0, .1, z1 - z0), oscuro, bisel=0, desorden=False, color=(1, 1, 1))
        for i in range(5):
            x = x0 + (i + .5) * (x1 - x0) / 5
            p.caja((x, FRENTE + .05, (z0 + z1) / 2), (.04, .04, z1 - z0), hierro, bisel=.005, desorden=False, color=(1, 1, 1))
        for z in (z0 + .25, z1 - .25):
            p.caja((0, FRENTE + .04, z), (x1 - x0, .03, .05), hierro, bisel=.005, desorden=False, color=(1, 1, 1))
        p.caja((0, FRENTE - .08 + .15, z0 - .07), (x1 - x0 + .25, .3, .14), piedra, bisel=.03)
        p.caja((0, FRENTE - .08 + .15, z1 + .08), (x1 - x0 + .25, .3, .16), piedra, bisel=.03)
    if tipo == "columna":
        _pilastra(p, piedra, 0)
    if tipo == "rota":
        for k in range(6):   # cascotes al pie
            t = R.uniform(.12, .3)
            p.caja((R.uniform(-.8, .8), FRENTE - R.uniform(.15, .55), t / 2), (t * 1.3, t, t), piedra,
                   giro=(R.uniform(-.3, .3), R.uniform(-.3, .3), R.uniform(0, 3)))
    if tipo == "hiedra":
        hoja = material("hiedra", (0.16, 0.24, 0.08), rugosidad=.8)
        for k in range(R.randint(3, 5)):
            x = R.uniform(-.85, .85)
            largo = R.uniform(.8, 2.3)
            for j in range(int(largo / .09)):
                z = ALTO_MURO - .1 - j * .09
                x += R.uniform(-.04, .04)
                t = R.uniform(.07, .14) * (1 - j * .09 / largo * .5)
                p.caja((x + R.uniform(-.05, .05), FRENTE - .12, z), (t, .03, t), hoja, bisel=.01,
                       color=(R.uniform(.7, 1.2),) * 3, giro=(0, R.uniform(-.6, .6), R.uniform(-.4, .4)))
    return p.crear()


def _pilastra(p, piedra, cx, sale=.38, ancho=.62):
    """pilastra adosada a la cara en x = cx: basa, fuste de tambores y capitel"""
    p.caja((cx, FRENTE - sale - .08 + .3, .25), (ancho + .22, .6, .5), piedra, bisel=.06)
    p.caja((cx, FRENTE - sale - .04 + .3, .58), (ancho + .1, .6, .16), piedra, bisel=.04)
    z = .66
    for h in hiladas(IMPOSTA - .3 - z, .32, .44):
        p.caja((cx, FRENTE - sale + .3, z + h / 2), (ancho, .6, h - JUNTA), piedra, bisel=.05)
        z += h
    p.caja((cx, FRENTE - sale - .04 + .3, z + .07), (ancho + .1, .6, .14), piedra, bisel=.03)
    p.caja((cx, FRENTE - sale - .1 + .3, z + .14 + .1), (ancho + .26, .6, .2), piedra, bisel=.04)


def columna_esquina(nombre):
    """columna gruesa en la esquina suroeste de la casilla (Godot la gira a la esquina que toque)"""
    p = Pieza(nombre)
    piedra = material("piedra", (0.42, 0.37, 0.33))
    cx, cy = -CELDA / 2, -CELDA / 2
    a = .8
    p.caja((cx, cy, .25), (a + .3, a + .3, .5), piedra, bisel=.07)
    p.caja((cx, cy, .58), (a + .15, a + .15, .16), piedra, bisel=.04)
    z = .66
    for h in hiladas(IMPOSTA + .2 - z, .34, .46):
        p.caja((cx, cy, z + h / 2), (a, a, h - JUNTA), piedra, bisel=.06, giro=(0, 0, math.radians(R.uniform(-3, 3))))
        z += h
    p.caja((cx, cy, z + .1), (a + .2, a + .2, .2), piedra, bisel=.04)
    p.caja((cx, cy, z + .3), (a + .34, a + .34, .22), piedra, bisel=.05)
    z += .41
    p.caja((cx, cy, (z + ALTO_MURO + .25) / 2), (a + .1, a + .1, ALTO_MURO + .25 - z), piedra, bisel=.05)
    return p.crear()


def nucleo(nombre):
    """el bloque de la casilla: liso por los lados (las caras lo tapan) y con tapa de losas desiguales"""
    p = Pieza(nombre)
    piedra = material("piedra", (0.42, 0.37, 0.33))
    p.caja((0, 0, (ALTO_MURO - .15) / 2), (CELDA, CELDA, ALTO_MURO - .15), piedra, bisel=0, color=(.6, .55, .5), desorden=False)
    cortes = [0, R.uniform(.7, 1.3), CELDA]
    for i in range(2):
        cortes2 = [0, R.uniform(.6, 1.4), CELDA]
        for j in range(2):
            x0, x1 = cortes[i] - CELDA / 2, cortes[i + 1] - CELDA / 2
            y0, y1 = cortes2[j] - CELDA / 2, cortes2[j + 1] - CELDA / 2
            h = R.uniform(.18, .32)
            p.caja(((x0 + x1) / 2, (y0 + y1) / 2, ALTO_MURO - .15 + h / 2 - .05), (x1 - x0 - .05, y1 - y0 - .05, h), piedra, bisel=.06)
    return p.crear()


# ---------------------------------------------------------------- todo
def main(salida):
    limpiar()
    muro("muro")          # el bloque antiguo (por si se quiere volver)
    nucleo("nucleo")
    nucleo("nucleo_b")
    cara("cara", "lisa")
    cara("cara_b", "lisa")
    cara("cara_columna", "columna")
    cara("cara_nicho", "nicho")
    cara("cara_arco_ciego", "arco_ciego")
    cara("cara_puerta", "puerta")
    cara("cara_reja", "reja")
    cara("cara_rota", "rota")
    cara("cara_hiedra", "hiedra")
    columna_esquina("columna_esquina")
    suelo("suelo", [(0, 0, 1, 1), (1, 0, 2, 1), (0, 1, 1, 2), (1, 1, 2, 2)])
    suelo("suelo_b", [(0, 0, 1.2, .8), (1.2, 0, 2, .8), (0, .8, .7, 2), (.7, .8, 2, 1.4), (.7, 1.4, 2, 2)])
    suelo("suelo_sala", [(0, 0, .65, .65), (.65, 0, 1.35, .65), (1.35, 0, 2, .65), (0, .65, .65, 1.35), (.65, .65, 1.35, 1.35),
                         (1.35, .65, 2, 1.35), (0, 1.35, .65, 2), (.65, 1.35, 1.35, 2), (1.35, 1.35, 2, 2)])
    pilar("pilar")
    arco("arco")
    antorcha("antorcha")
    brasero("brasero")
    estandarte("estandarte")
    barril("barril")
    caja_madera("caja")
    # separar las piezas en el .blend para verlas (en Godot se centran solas)
    for i, o in enumerate(bpy.data.objects):
        o.location.x = (i % 6) * 3
        o.location.y = (i // 6) * 3
    bpy.ops.export_scene.gltf(filepath=salida, export_format="GLB", export_apply=True,
                              export_vertex_color="ACTIVE", export_all_vertex_colors=False)
    print("kit exportado:", salida, len(bpy.data.objects), "piezas")


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    main(args[0] if args else "assets/kit/kit_mazmorra.glb")
