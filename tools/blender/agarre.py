"""Agarres de armas (espada, escudo…) en las manos de un personaje de Mixamo.

Un agarre es la matriz del arma respecto al hueso de la mano: posición en metros, giro y escala,
medida desde la base del hueso (igual que BoneAttachment3D en Godot) y sin la escala 0,01 de Mixamo.
Se guarda en la ficha del personaje de SPRITE_FACTORY, aparte del «offset» de la fábrica de sprites:

  "agarres_3d": {
    "main_hand": {"espada": {"file": "weapons/x.glb", "m": [16 números, por filas]}},
    "off_hand":  {"escudo": {...}, "espada": {...}}
  }

Lo usan colocar_arma.py (el panel de Blender) y monstruos_glb.py (el conversor).
"""
import bpy
import json
import os
import shutil
from mathutils import Matrix

HUESO = {"main_hand": "mixamorig:RightHand", "off_hand": "mixamorig:LeftHand"}
MANOS = ("main_hand", "off_hand")
TIPOS = ("espada", "escudo")
HEROE = "esqueleto"   # sus agarres valen para todos los de Mixamo que no tengan los suyos


def importar(ruta):
    antes = set(bpy.data.objects)
    if ruta.lower().endswith(".fbx"):
        bpy.ops.import_scene.fbx(filepath=ruta, automatic_bone_orientation=False)
    else:
        bpy.ops.import_scene.gltf(filepath=ruta)
    return [o for o in bpy.data.objects if o not in antes]


def cargar_arma(ruta, nombre, max_caras=4000):
    """importa un arma (.glb o .fbx) y la deja en una sola malla, tal como viene en su archivo"""
    nuevos = importar(ruta)
    mallas = [o for o in nuevos if o.type == "MESH"]
    for o in nuevos:
        if o.type != "MESH":
            bpy.data.objects.remove(o, do_unlink=True)
    if not mallas:
        return None
    bpy.ops.object.select_all(action="DESELECT")
    for o in mallas:
        o.select_set(True)
    bpy.context.view_layer.objects.active = mallas[0]
    if len(mallas) > 1:
        bpy.ops.object.join()
    w = bpy.context.view_layer.objects.active
    # sin padre (el importador de glTF a veces cuelga las mallas de un vacío): se queda donde estaba
    mw = w.matrix_world.copy()
    w.parent = None
    w.matrix_world = mw
    w.name = nombre
    n = len(w.data.polygons)
    if n > max_caras:
        m = w.modifiers.new("reducir", "DECIMATE")
        m.ratio = max_caras / n
        bpy.ops.object.modifier_apply(modifier=m.name)
    return w


def tipo_de(nombre):
    n = nombre.lower()
    return "escudo" if any(p in n for p in ("shield", "escudo", "buckler", "pavés", "paves")) else "espada"


def marco(arm, mano):
    """matriz del hueso de la mano en el mundo, en metros (sin la escala del esqueleto)"""
    pb = arm.pose.bones[HUESO[mano]]
    b = arm.matrix_world @ pb.matrix
    loc, rot, _ = b.decompose()
    return Matrix.LocRotScale(loc, rot, None)


def a_lista(m):
    return [round(m[i][j], 6) for i in range(4) for j in range(4)]


def de_lista(l):
    return Matrix([l[0:4], l[4:8], l[8:12], l[12:16]])


def medir(arm, mano, obj):
    """el agarre de un objeto colocado en la escena"""
    bpy.context.view_layer.update()
    return marco(arm, mano).inverted() @ obj.matrix_world


def poner(arm, mano, obj, m):
    """cuelga el objeto del hueso y lo coloca con el agarre m"""
    bpy.context.view_layer.update()
    mw = marco(arm, mano) @ m
    obj.parent = arm
    obj.parent_type = "BONE"
    obj.parent_bone = HUESO[mano]
    obj.matrix_parent_inverse = Matrix.Identity(4)
    bpy.context.view_layer.update()
    obj.matrix_world = mw
    bpy.context.view_layer.update()


def espejo(arm, m_der):
    """el agarre de la mano izquierda reflejando el de la derecha (en la pose de reposo)"""
    antes = arm.data.pose_position
    arm.data.pose_position = "REST"
    bpy.context.view_layer.update()
    s = Matrix.Diagonal((-1, 1, 1, 1))
    # el personaje está centrado en x = 0 y mira hacia -y: se refleja en x, en el mundo y en el arma
    w = s @ (marco(arm, "main_hand") @ m_der) @ s
    m = marco(arm, "off_hand").inverted() @ w
    arm.data.pose_position = antes
    bpy.context.view_layer.update()
    return m


def leer(cfg, mano, tipo):
    return cfg.get("agarres_3d", {}).get(mano, {}).get(tipo)


def guardar(ruta_ficha, mano, tipo, fichero, m):
    """escribe el agarre en la ficha (la primera vez deja una copia .bak)"""
    if not os.path.exists(ruta_ficha + ".bak"):
        shutil.copyfile(ruta_ficha, ruta_ficha + ".bak")
    with open(ruta_ficha, encoding="utf-8") as f:
        cfg = json.load(f)
    cfg.setdefault("agarres_3d", {}).setdefault(mano, {})[tipo] = {"file": fichero.replace("\\", "/"), "m": a_lista(m)}
    with open(ruta_ficha, "w", encoding="utf-8") as f:
        json.dump(cfg, f, indent=2, ensure_ascii=False)
    return cfg


def agarres(factory, cfg):
    """los agarres que valen para un personaje: los suyos y, donde no tenga, los del héroe"""
    res = {}
    heroe = {}
    rh = os.path.join(factory, "config/characters", HEROE + ".json")
    if os.path.exists(rh):
        with open(rh, encoding="utf-8") as f:
            heroe = json.load(f).get("agarres_3d", {})
    propios = cfg.get("agarres_3d", {})
    for mano in MANOS:
        for tipo in TIPOS:
            a = propios.get(mano, {}).get(tipo) or heroe.get(mano, {}).get(tipo)
            if a:
                res[(mano, tipo)] = a
    return res
