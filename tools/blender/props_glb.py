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
import fnmatch
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
#  Modelos sueltos (Tripo, un .glb por pieza): "archivo": patrón del archivo de la carpeta de entrada,
#  "alto" / "ancho" / "fondo": medida final en metros (en lugar de "escala"),
#  "brillo": fuerza del brillo de lo que es lava en su color (grietas naranjas), 0 = nada;
#  "brillo_color": "cian" para que brille lo azul claro encendido (cristales, cuencos) en lugar de lo naranja.
# ---------------------------------------------------------------------------
_TRIPO_INFRA = {
    "pilar_retorcido": {"archivo": "lava column*.glb", "alto": 3.6, "tris": 9000, "brillo": 3.0},
    "muro_calavera": {"archivo": "stone skull wall*.glb", "alto": 3.0, "tris": 8000, "brillo": 2.5},
    "remate_punta": {"archivo": "stone gothic tower*.glb", "alto": 1.5, "tris": 4000, "brillo": 2.5},
    "brasero_piedra": {"archivo": "fantasy stone brazier*.glb", "alto": 1.3, "tris": 7000, "brillo": 3.0},
    "estalagmitas": {"archivo": "lava rock 3d*.glb", "alto": 2.2, "tris": 5000, "brillo": 3.0},
    "roca_borde": {"archivo": "lava rock platform*.glb", "ancho": 2.4, "tris": 6000, "brillo": 3.0},
    "puerta_demoniaca": {"archivo": "hell gate arch*.glb", "alto": 4.4, "tris": 14000, "brillo": 3.0},
}
_TRIPO_PUENTE = {
    "tramo_puente": {"archivo": "dungeon stone arch*.glb", "fondo": 6.4, "tris": 20000, "brillo": 3.0},
    "puente_lejano": {"archivo": "gothic stone bridge*.glb", "ancho": 34.0, "tris": 10000, "brillo": 2.0},
    "acantilado": {"archivo": "lava rock pillar*.glb", "alto": 16.0, "tris": 12000, "brillo": 3.5},
    "estalactitas": {"archivo": "lava rock formation*.glb", "ancho": 6.0, "tris": 6000, "brillo": 2.5},
    "cadena": {"archivo": "rusty chain*.glb", "alto": 3.0, "tris": 3000},
    "jaula": {"archivo": "rusty spiked cage*.glb", "alto": 2.3, "tris": 9000},
}

_TRIPO_ABISMO = {   # sala especial «Abismo de cristal» (Galerías hundidas); dibujos en C:\Carpeta Juego\Escenas\abismo_cristal\piezas_tripo
    "estatua_cuenco": {"archivo": "female statue*.glb", "alto": 3.2, "tris": 12000},   # el agua que brilla del cuenco la pone la escena («disco»)
    "hornacina": {"archivo": "stone archway*.glb", "alto": 4.6, "tris": 8000},
    "cristales_grande": {"archivo": "blue crystal cluster 3d model (1).glb", "alto": 2.4, "tris": 8000, "brillo": 2.2, "brillo_color": "cian"},
    "cristales_pequeno": {"archivo": "blue crystal cluster 3d model.glb", "alto": .9, "tris": 4000, "brillo": 2.2, "brillo_color": "cian"},
    "pebetero": {"archivo": "rusty brazier*.glb", "alto": .8, "tris": 5000},
    "poste_pretil": {"archivo": "stone pedestal*.glb", "alto": 1.15, "tris": 2500},
    "tramo_pretil": {"archivo": "stone balustrade*.glb", "ancho": 2.4, "tris": 4000},
    "arco_puente": {"archivo": "stone arch ruin*.glb", "ancho": 8.0, "tris": 10000},
    "arco_entrada": {"archivo": "ancient stone arch*.glb", "ancho": 6.8, "tris": 12000},
    "roca_acantilado": {"archivo": "rocky cliff*.glb", "alto": 6.0, "tris": 6000},
}

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
    # ---- Tripo (Diego, Premium: uso comercial): un .glb por pieza ----
    "inframundo": {"fuente": [v["archivo"] for v in _TRIPO_INFRA.values()], "escala": 1.0, "piezas": _TRIPO_INFRA, "max_px": 1024},
    "puente": {"fuente": [v["archivo"] for v in _TRIPO_PUENTE.values()], "escala": 1.0, "piezas": _TRIPO_PUENTE, "max_px": 1024},
    "abismo_cristal": {"fuente": [v["archivo"] for v in _TRIPO_ABISMO.values()], "escala": 1.0, "piezas": _TRIPO_ABISMO, "max_px": 1024},
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
            antes = set(bpy.context.scene.objects)
            bpy.ops.import_scene.gltf(filepath=r)
            for o in set(bpy.context.scene.objects) - antes:
                o["archivo"] = os.path.basename(r)
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


def brillo_lava(o, fuerza, color="lava"):
    """lo naranja encendido del color (grietas de lava) pasa a brillar: textura de emisión = color × máscara.
    color="cian": lo azul claro encendido (cristales, cuencos de agua que brillan)"""
    import numpy as np
    for s_ in o.material_slots:
        m = s_.material
        if m is None or not m.use_nodes:
            continue
        nt = m.node_tree
        bsdf = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
        if bsdf is None or not bsdf.inputs["Base Color"].links:
            continue
        tex = bsdf.inputs["Base Color"].links[0].from_node
        if tex.type != "TEX_IMAGE" or tex.image is None:
            continue
        im = tex.image
        w, h = im.size
        px = np.empty(w * h * 4, dtype=np.float32)
        im.pixels.foreach_get(px)
        px = px.reshape(-1, 4)
        r, g, b = px[:, 0], px[:, 1], px[:, 2]
        if color == "cian":
            calor = np.clip((np.minimum(g, b) - r) * 2.2 - .1, 0, 1)   # más verde y azul que rojo
            luz = np.clip((np.maximum(g, b) - .45) * 2.2, 0, 1)
        else:
            calor = np.clip((r - b) * 1.6 - .25, 0, 1)
            luz = np.clip((np.maximum(r, g) - .35) * 2.2, 0, 1)
        k = np.clip(calor * luz * 1.4, 0, 1)
        out = px.copy()
        out[:, :3] *= k[:, None]
        out[:, 3] = 1
        em = bpy.data.images.new(im.name + "_brillo", w, h)
        em.pixels.foreach_set(out.ravel())
        em.pack()
        n = nt.nodes.new("ShaderNodeTexImage")
        n.image = em
        nt.links.new(tex.inputs["Vector"].links[0].from_socket if tex.inputs["Vector"].links else n.inputs["Vector"], n.inputs["Vector"]) if tex.inputs["Vector"].links else None
        nt.links.new(n.outputs["Color"], bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = fuerza
        print(f"    {o.name}: brilla el {100 * (k > .5).mean():.1f} % del color")


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
        if "archivo" in p:
            objs = [o for o in bpy.context.scene.objects if o.type == "MESH" and fnmatch.fnmatch(o.get("archivo", ""), p["archivo"])]
        else:
            objs = [o for g, os_ in G.items() if any(re.search(rx, g) for rx in p["de"]) for o in os_]
        if not objs:
            print(f"  {nombre}/{n}: no hay grupo que case con {p['de']}")
            continue
        o = unir(objs, n)
        reducir(o, p.get("tris"))
        if cfg.get("giro"):
            o.data.transform(__import__("mathutils").Matrix.Rotation(math.radians(cfg["giro"]), 4, "Z"))
        esc = cfg["escala"] * p.get("escala", 1.0)
        for k, eje in (("alto", 2), ("ancho", 0), ("fondo", 1)):
            if k in p:
                vs = [v.co[eje] for v in o.data.vertices]
                esc = p[k] / max(max(vs) - min(vs), 1e-6)
        colocar(o, esc, p.get("origen", "base"))
        if p.get("brillo"):
            brillo_lava(o, p["brillo"], p.get("brillo_color", "lava"))
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
