"""Paquetes de modelos de fuera (Poly Haven, Sketchfab) → .glb listos para Godot.

Uso (módulo bpy: pip install bpy):
    python3 tools/blender/props_glb.py <carpeta_entrada> assets/props [paquete …]
    python3 tools/blender/props_glb.py <carpeta_entrada> --listar <paquete>

<carpeta_entrada> tiene lo que Diego pasó, tal cual:
    los .glb de Sketchfab y una carpeta por cada .blend de Poly Haven (el zip descomprimido).

Cada paquete sale como UN .glb en assets/props/<paquete>.glb con una pieza por objeto, ya:
  · con todas las transformaciones aplicadas y la escala del juego (casilla = 2 m, muro = 3 m),
  · con el origen abajo en el centro (o atrás, para lo que se cuelga de la pared,
    o en la bisagra, para la tapa del cofre) y colocada en el origen,
  · con menos polígonos donde sobraban (Decimate) y texturas de 1024 px como mucho.
Godot elige cada pieza por su nombre (ver src/vista3d/props3d.gd).
Las licencias y los autores están en docs/CREDITOS_Y_LICENCIAS.md.
"""
import bpy
import bmesh
import glob
import math
import os
import re
import sys
from mathutils import Vector

ENVOLTORIOS = ("sketchfab_model", "rootnode", "gltf_scenerootnode", ".fbx", "collada", "root", "world")

# ---------------------------------------------------------------------------
#  paquetes
#  fuente: archivo dentro de la carpeta de entrada (glob)
#  escala: factor para pasar a metros del juego
#  piezas: nombre de salida → {"de": [grupos de origen (regex)], "tris": máximo, "origen": base|atras|bisagra,
#          "escala": factor extra}
#  Si "piezas" es "*", salen todos los grupos con su nombre limpio.
# ---------------------------------------------------------------------------
PAQUETES = {
    # ---- Poly Haven (CC0), tamaño real ----
    "polyhaven": {
        "fuente": [
            "treasure_chest_1k/*.blend", "lion_head_1k/*.blend", "wooden_crate_01_1k/*.blend",
            "WoodenChair_01_1k/*.blend", "rock_moss_set_02_1k/*.blend", "rock_face_02_1k/*.blend",
            "namaqualand_stones_01_1k/*.blend", "dandelion_01_1k/*.blend",
        ],
        "escala": 1.0,
        "piezas": {
            "cofre": {"de": [r"^treasure_chest_(bottom|handle_left|handle_right|lock)$"], "tris": 9000},
            "cofre_tapa": {"de": [r"^treasure_chest_lid$"], "tris": 6000, "origen": "bisagra"},
            "cabeza_leon": {"de": [r"^lion_head$"], "tris": 6000, "origen": "atras", "escala": 1.6},
            "caja": {"de": [r"^wooden_crate_01(_lid|_latch)?$"], "tris": 6000},
            "silla": {"de": [r"^WoodenChair_01$"], "tris": 6000, "escala": .55},
            **{f"roca_musgo_{i}": {"de": [rf"^rock_moss_set_02_rock{i:02d}$"], "tris": 3000} for i in range(7, 14)},
            "roca_grande": {"de": [r"^rock_face_02$"], "tris": 7000},
            **{f"piedras_{l}": {"de": [rf"^namaqualand_stones_01_{l}_LOD2$"], "tris": 2500, "escala": 2.5} for l in "abcde"},
            **{f"diente_leon_{l}": {"de": [rf"^dandelion_01_{l}_LOD1$"], "tris": 2000} for l in "abcde"},
        },
        "max_px": 1024,
    },
    # ---- Modular Dungeon Kit · HenryBoadle (CC-BY 4.0): el muro Wall_01 mide una casilla ----
    "dungeon_kit": {
        "fuente": ["*modular_dungeon_kit.glb"],
        "escala": 3.45,
        "giro": 90,   # sus muros corren a lo largo de Y: se giran para que corran a lo largo de X y den la cara a -Y
        "piezas": {
            "muro": {"de": [r"^Wall_01$"], "tris": 4000},
            "muro_b": {"de": [r"^Wall2_01$"], "tris": 3000},
            "muro_c": {"de": [r"^Wall3_01$"], "tris": 5000},
            "muro_d": {"de": [r"^Wall4_01$"], "tris": 4000},
            "losa_1": {"de": [r"^Tile1_01$"]},
            "losa_2": {"de": [r"^Tile2_01$"]},
            "losa_3": {"de": [r"^Tile3_01$"]},
            "pilar": {"de": [r"^Pillar_01$"]},
            "estandarte_1": {"de": [r"^Banner_01$"], "origen": "atras"},
            "estandarte_2": {"de": [r"^Banner_02$"], "origen": "atras"},
            "estandarte_3": {"de": [r"^Banner_03$"], "origen": "atras"},
            "barril": {"de": [r"^BarrelClosed_01$"], "tris": 2500},
            "barril_abierto": {"de": [r"^BarrelOpen_01$"], "tris": 2500},
            "barril_roto": {"de": [r"^BarrelBroken_01$"], "tris": 2500},
            "brasero": {"de": [r"^Braiser_01$"]},
            "antorcha": {"de": [r"^WallTorch_01$"], "origen": "atras"},
            "roca": {"de": [r"^Rock_01$"]},
            "piedra": {"de": [r"^Rock2_01$"]},
        },
        "max_px": 1024,
    },
    # ---- Weapon set · rudolfs (CC-BY 4.0) ----
    "armas": {
        "fuente": ["*weapon_set.glb"],
        "escala": 1.1,
        "piezas": {
            "espada": {"de": [r"^Sword"]}, "hacha": {"de": [r"^Axe"]}, "garrote": {"de": [r"^Club"]},
            "daga": {"de": [r"^Dagger"]}, "martillo": {"de": [r"^Hammer"]}, "guadana": {"de": [r"^Scythe"]},
            "lanza": {"de": [r"^Spear"]}, "escudo": {"de": [r"^Shield"]},
        },
        "max_px": 1024,
    },
    # ---- Ancient Ruins Pack · Toni García Vilche (CC-BY 4.0) ----
    "ruinas": {"fuente": ["*ancient_ruins_pack.glb"], "escala": 1.25, "piezas": "*", "tris": 6000, "max_px": 1024},
    # ---- Free Modular Low Poly Dungeon Pack · RgsDev (CC-BY 4.0): muro de 2,1 m → 2 m ----
    "low_poly": {"fuente": ["*free_modular_low_poly_dungeon_pack.glb"], "escala": 0.95, "piezas": "*", "max_px": 512},
    # ---- Gothic Interior Kit (Mid-Poly) · Zver 3D (CC-BY 4.0): muros de 2 m de ancho ----
    "gotico": {"fuente": ["*gothic_interior_kit_mid-poly.glb"], "escala": 1.0, "piezas": "*", "tris": 9000, "max_px": 512},
}


# ---------------------------------------------------------------------------
def limpio(n: str) -> str:
    n = re.sub(r"_\d+$", "", n)                       # sufijo de Sketchfab (_0, _12…)
    n = n.lower().replace(" ", "_").replace("'", "")
    n = re.sub(r"[^a-z0-9_]+", "_", n)
    return re.sub(r"_+", "_", n).strip("_")


def es_envoltorio(o) -> bool:
    n = o.get("nombre", o.name).lower()
    return any(e in n for e in ENVOLTORIOS) or o.parent is None and o.type == "EMPTY"


def grupo_de(o) -> str:
    """el antepasado más alto que no es un envoltorio de Sketchfab (o el propio objeto)"""
    g = o
    p = o.parent
    while p is not None and not es_envoltorio(p):
        g = p
        p = p.parent
    n = g.get("nombre", g.name)
    if g.type == "MESH" and g.parent is not None and es_envoltorio(g.parent):
        # Sketchfab parte cada objeto por material: «Wall_01_lambert10_0» → «Wall_01»
        n = re.sub(r"_[^_]*(lambert|Material|material|Estructura|BLACK|Wall_02)[^_]*_\d+$", "", n)
        n = re.sub(r"_(grey|dark_grey|light_grey|dark grey|light grey|beige|black|brown|dark brown|light brown|yellow|red|material)_\d+$", "", n)
    return n


def importar(rutas):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for r in rutas:
        if r.endswith(".blend"):
            with bpy.data.libraries.load(r, link=False) as (src, dst):
                dst.objects = list(src.objects)
            for o in dst.objects:
                if o is not None and o.type == "MESH":
                    bpy.context.scene.collection.objects.link(o)
        else:
            bpy.ops.import_scene.gltf(filepath=r)
    bpy.context.view_layer.update()
    # los originales llevan prefijo, para que las piezas de salida puedan quedarse con su nombre limpio
    for o in bpy.context.scene.objects:
        o["nombre"] = o.name
    for o in bpy.context.scene.objects:
        o.name = "__src__" + o.name


def grupos() -> dict:
    out = {}
    for o in bpy.context.scene.objects:
        if o.type == "MESH":
            out.setdefault(grupo_de(o), []).append(o)
    return out


def unir(objs, nombre):
    """une los objetos en uno nuevo, con la transformación del mundo aplicada"""
    bpy.ops.object.select_all(action="DESELECT")
    copias = []
    for o in objs:
        c = o.copy()
        c.data = o.data.copy()
        bpy.context.scene.collection.objects.link(c)
        mw = o.matrix_world.copy()
        c.parent = None
        c.matrix_world = mw
        copias.append(c)
    bpy.context.view_layer.update()
    for c in copias:
        c.data.transform(c.matrix_world)
        c.matrix_world = c.matrix_world.__class__.Identity(4)
    if len(copias) > 1:
        with bpy.context.temp_override(active_object=copias[0], selected_editable_objects=copias):
            bpy.ops.object.join()
    o = copias[0]
    o.name = nombre
    o.data.name = nombre
    return o


def contar_tris(o) -> int:
    return sum(len(p.vertices) - 2 for p in o.data.polygons)


def reducir(o, tris_max):
    t = contar_tris(o)
    if not tris_max or t <= tris_max:
        return
    m = o.modifiers.new("menos", "DECIMATE")
    m.ratio = max(.02, tris_max / t)
    m.use_collapse_triangulate = True
    with bpy.context.temp_override(object=o, active_object=o):
        bpy.ops.object.modifier_apply(modifier=m.name)


BISAGRAS = {}


def colocar(o, escala, origen):
    """escala, y origen abajo en el centro (o atrás / en la bisagra) en (0, 0, 0). En Blender Z es arriba
    y el frente mira a -Y (sale como +Z en Godot)."""
    o.data.transform(__import__("mathutils").Matrix.Scale(escala, 4))
    vs = [v.co for v in o.data.vertices]
    mn = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
    mx = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
    c = (mn + mx) / 2
    if origen == "atras":       # lo que se cuelga: el origen en la cara de atrás, a media altura
        p = Vector((c.x, mx.y, c.z))
    elif origen == "bisagra":   # tapa del cofre: el borde de atrás, abajo
        p = Vector((c.x, mx.y, mn.z))
    else:
        p = Vector((c.x, c.y, mn.z))
    BISAGRAS[o.name] = p.copy()   # el punto que pasa a ser el origen, en el sitio original (ya escalado)
    o.data.transform(__import__("mathutils").Matrix.Translation(-p))
    o.location = (0, 0, 0)


def texturas(objs, max_px):
    """el color a max_px; normales, rugosidad y metal a la mitad. Todo en JPEG salvo lo que lleva transparencia."""
    vistas = set()
    for o in objs:
        for s in o.material_slots:
            if s.material is None or not s.material.use_nodes:
                continue
            for n in s.material.node_tree.nodes:
                if n.type == "TEX_IMAGE" and n.image is not None and n.image.name not in vistas:
                    im = n.image
                    vistas.add(im.name)
                    color = any(l.to_socket.name in ("Base Color",) for l in n.outputs[0].links)
                    alfa = any(l.to_socket.name == "Alpha" for l in n.outputs["Alpha"].links) or "alpha" in im.name.lower() or "mask" in im.name.lower()
                    lado = max_px if color else max_px // 2
                    w, h = im.size
                    if max(w, h) > lado:
                        f = lado / max(w, h)
                        im.scale(max(1, int(w * f)), max(1, int(h * f)))
                    im.file_format = "PNG" if alfa else "JPEG"


def exportar(objs, ruta):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    os.makedirs(os.path.dirname(ruta), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=ruta, export_format="GLB", use_selection=True, export_apply=True,
                              export_image_format="WEBP", export_image_quality=85, export_yup=True, export_animations=False)


def paquete(entrada, salida, nombre):
    BISAGRAS.clear()
    cfg = PAQUETES[nombre]
    rutas = []
    for f in cfg["fuente"]:
        rutas += sorted(glob.glob(os.path.join(entrada, f)))
    if not rutas:
        print(f"  {nombre}: no encuentro {cfg['fuente']} en {entrada}")
        return
    importar(rutas)
    G = grupos()
    piezas = cfg["piezas"]
    if piezas == "*":
        piezas = {}
        usados = set()
        for g in sorted(G):
            n = limpio(g)
            while n in usados:
                n += "_b"
            usados.add(n)
            piezas[n] = {"de": ["^" + re.escape(g) + "$"], "tris": cfg.get("tris")}
    hechos = []
    for n, p in piezas.items():
        objs = [o for g, os_ in G.items() if any(re.search(rx, g) for rx in p["de"]) for o in os_]
        if not objs:
            print(f"  {nombre}/{n}: no hay grupo que case con {p['de']}")
            continue
        o = unir(objs, n)
        reducir(o, p.get("tris"))
        if cfg.get("giro"):
            o.data.transform(__import__("mathutils").Matrix.Rotation(math.radians(cfg["giro"]), 4, "Z"))
        colocar(o, cfg["escala"] * p.get("escala", 1.0), p.get("origen", "base"))
        hechos.append(o)
    # fuera lo que no sale
    for o in list(bpy.context.scene.objects):
        if o not in hechos:
            bpy.data.objects.remove(o, do_unlink=True)
    texturas(hechos, cfg.get("max_px", 1024))
    ruta = os.path.join(salida, nombre + ".glb")
    exportar(hechos, ruta)
    if "cofre" in BISAGRAS and "cofre_tapa" in BISAGRAS:
        d = BISAGRAS["cofre_tapa"] - BISAGRAS["cofre"]
        # Blender (x, y, z) → Godot (x, z, -y)
        print(f"  bisagra de la tapa respecto al cofre (Godot): Vector3({d.x:.3f}, {d.z:.3f}, {-d.y:.3f})")
    tot = sum(contar_tris(o) for o in hechos)
    print(f"  {nombre}: {len(hechos)} piezas, {tot} triángulos → {ruta} ({os.path.getsize(ruta) / 1e6:.1f} MB)")
    for o in hechos:
        d = o.dimensions
        print(f"    {o.name:28s} {d.x:5.2f} x {d.y:5.2f} x {d.z:5.2f} m  {contar_tris(o):6d} tris")


def listar(entrada, nombre):
    cfg = PAQUETES[nombre]
    rutas = []
    for f in cfg["fuente"]:
        rutas += sorted(glob.glob(os.path.join(entrada, f)))
    importar(rutas)
    for g, objs in sorted(grupos().items()):
        print(f"  {g!r}: {len(objs)} mallas")


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    entrada = args[0]
    if len(args) > 2 and args[1] == "--listar":
        listar(entrada, args[2])
    else:
        salida = args[1]
        for n in (args[2:] or list(PAQUETES)):
            paquete(entrada, salida, n)
