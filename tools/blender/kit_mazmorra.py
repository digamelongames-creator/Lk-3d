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
ALTO_MURO = 2.5
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


# ---------------------------------------------------------------- todo
def main(salida):
    limpiar()
    muro("muro")
    muro("muro_b")
    muro("muro_c")
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
