"""Pasa los personajes de SPRITE_FACTORY (Mixamo) a un .glb por personaje con todas sus animaciones.

Uso:  python3 tools/blender/monstruos_glb.py <carpeta SPRITE_FACTORY> <carpeta de salida> [id …]

Lee config/characters/<id>.json (base, juego de animaciones, armas) y config/animation_sets/<set>.json
(qué .fbx es cada acción, tramo, si se quita el desplazamiento), igual que la fábrica de sprites, y deja
<salida>/<id>.glb con las animaciones idle, walk, run, attack, hurt, death (y jump si la hay).
Las armas del «loadout» van pegadas al hueso de la mano; en Godot salen como BoneAttachment3D.
Si la ficha tiene agarres colocados con colocar_arma.py («agarres_3d»), mandan sobre el «offset».
Además, cada agarre que valga para el personaje sale como «agarre_<mano>_<tipo>» (escondido en el juego),
para que Godot pueda poner cualquier arma del equipo: espada a la derecha, escudo o segunda espada a la izquierda.
"""
import bpy  # antes que bmesh/mathutils con el módulo bpy de pip
import json
import math
import os
import sys
from mathutils import Euler, Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import agarre as AG  # noqa: E402

SLOT_HUESO = {"main_hand": "mixamorig:RightHand", "off_hand": "mixamorig:LeftHand"}


def limpiar():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for coll in (bpy.data.actions, bpy.data.meshes, bpy.data.armatures, bpy.data.materials, bpy.data.images):
        for x in list(coll):
            if x.users == 0 or coll is bpy.data.actions:
                coll.remove(x)


def fcurves(action):
    if hasattr(action, "fcurves") and not hasattr(action, "layers"):
        return list(action.fcurves)
    res = []
    for layer in action.layers:
        for strip in layer.strips:
            for cb in strip.channelbags:
                res.extend(cb.fcurves)
    return res


def importar_fbx(ruta):
    antes = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=ruta, automatic_bone_orientation=False)
    return [o for o in bpy.data.objects if o not in antes]


def accion_de(ruta, nombre, tramo, quitar_raiz):
    """importa un .fbx de Mixamo (solo esqueleto), se queda con su acción y borra lo demás"""
    nuevos = importar_fbx(ruta)
    arm = next(o for o in nuevos if o.type == "ARMATURE")
    act = arm.animation_data.action
    act.name = nombre
    act.use_fake_user = True
    for fc in fcurves(act):
        # quitar el avance de la cadera en horizontal (x, z del hueso; y es la altura)
        if quitar_raiz and fc.data_path.endswith('["mixamorig:Hips"].location') and fc.array_index in (0, 2) and len(fc.keyframe_points):
            v = fc.keyframe_points[0].co.y
            for k in fc.keyframe_points:
                k.co.y = v
                k.handle_left.y = v
                k.handle_right.y = v
        fc.update()
    for o in nuevos:
        bpy.data.objects.remove(o, do_unlink=True)
    return act


def arma(ruta, arm, slot, off, factory, largo=None):
    nuevos = [o for o in importar_gltf(os.path.join(factory, ruta)) if o.type == "MESH"]
    if not nuevos:
        return
    bpy.ops.object.select_all(action="DESELECT")
    for o in nuevos:
        o.select_set(True)
    bpy.context.view_layer.objects.active = nuevos[0]
    if len(nuevos) > 1:
        bpy.ops.object.join()
    w = bpy.context.view_layer.objects.active
    w.name = "arma_" + slot
    reducir(w, 4000)
    hueso = SLOT_HUESO[slot]
    w.parent = arm
    w.parent_type = "BONE"
    w.parent_bone = hueso
    loc = Vector(off.get("location", (0, 0, 0)))
    rot = Euler([math.radians(a) for a in off.get("rotation_deg", (0, 0, 0))])
    sc = off.get("scale", 1.0)
    sc = Vector(sc) if isinstance(sc, list) else Vector((sc, sc, sc))
    w.matrix_parent_inverse = Matrix.Identity(4)
    # el esqueleto de Mixamo va a escala 0,01: las medidas del arma (en metros) se pasan a su escala
    k = 1.0 / arm.scale.x
    # el arma se lleva a su longitud de la ficha (length_m), como en la fábrica
    if largo:
        k *= largo / max(max(w.dimensions), 1e-6)
    w.location = loc / arm.scale.x
    w.rotation_euler = rot
    w.scale = sc * k


def poner_armas(factory, cfg, arm):
    ags = AG.agarres(factory, cfg)
    bpy.context.view_layer.update()
    for nombre, l in cfg.get("loadout", {}).items():
        a = ags.get((l["slot"], AG.tipo_de(nombre + " " + l["file"])))
        if a is None:
            arma(l["file"], arm, l["slot"], l.get("offset", {}), factory, l.get("length_m"))
            continue
        w = AG.cargar_arma(os.path.join(factory, l["file"]), "arma_" + l["slot"])
        if w is not None:
            AG.poner(arm, l["slot"], w, AG.de_lista(a["m"]))
    # los agarres para el equipo del juego; la espada izquierda, si no está colocada, sale reflejando la derecha
    if ("main_hand", "espada") in ags and ("off_hand", "espada") not in ags:
        e = dict(ags[("main_hand", "espada")])
        e["m"] = AG.a_lista(AG.espejo(arm, AG.de_lista(e["m"])))
        ags[("off_hand", "espada")] = e
    for (mano, tipo), a in ags.items():
        w = AG.cargar_arma(os.path.join(factory, a["file"]), "agarre_%s_%s" % (mano, tipo))
        if w is not None:
            AG.poner(arm, mano, w, AG.de_lista(a["m"]))


def reducir(o, max_caras):
    """baja los polígonos (los modelos de Tripo salen con cientos de miles) con un Decimate"""
    n = len(o.data.polygons)
    if n <= max_caras:
        return
    m = o.modifiers.new("reducir", "DECIMATE")
    m.ratio = max_caras / n
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.modifier_apply(modifier=m.name)
    print("  ", o.name, n, "->", len(o.data.polygons), "caras")


def importar_gltf(ruta):
    antes = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=ruta)
    return [o for o in bpy.data.objects if o not in antes]


def convertir(factory, salida, cid):
    cfg, arm = montar(factory, cid)
    exportar(salida, cid, arm)


def montar(factory, cid):
    """el personaje con todas sus animaciones (pistas NLA) y sus armas, listo para exportar"""
    limpiar()
    cfg = json.load(open(os.path.join(factory, "config/characters", cid + ".json")))
    aset = json.load(open(os.path.join(factory, "config/animation_sets", cfg["animation_set"] + ".json")))
    base = os.path.join(factory, cfg["base"])
    if not os.path.exists(base):   # mayúsculas distintas en Windows (Base.fbx, Middledemon/…)
        d = os.path.dirname(base)
        d = next((os.path.join(os.path.dirname(d), x) for x in os.listdir(os.path.dirname(d)) if x.lower() == os.path.basename(d).lower()), d)
        base = next(os.path.join(d, x) for x in os.listdir(d) if x.lower() == os.path.basename(base).lower())
    nuevos = importar_fbx(base)
    arm = next(o for o in nuevos if o.type == "ARMATURE")
    arm.name = cid
    for o in nuevos:
        if o.type == "MESH":
            reducir(o, 25000)
    if arm.animation_data and arm.animation_data.action:
        bpy.data.actions.remove(arm.animation_data.action)
    carpeta = os.path.join(factory, aset["folder"])
    ficheros = {x.lower(): x for x in os.listdir(carpeta)}
    if arm.animation_data is None:
        arm.animation_data_create()
    for clave, a in aset["actions"].items():
        fich = ficheros.get(a["file"].lower())
        if fich is None:
            print("  falta", a["file"])
            continue
        act = accion_de(os.path.join(carpeta, fich), clave, a.get("source_range"), a.get("root_motion") == "remove")
        tr = arm.animation_data.nla_tracks.new()
        tr.name = clave
        f0, f1 = act.frame_range
        if a.get("source_range"):   # el tramo de la acción que se usa, como en la fábrica de sprites
            f0, f1 = max(f0, a["source_range"][0]), min(f1, a["source_range"][1])
        st = tr.strips.new(clave, 0, act)
        st.action_frame_start = f0
        st.action_frame_end = f1
        st.frame_start = 0
        st.frame_end = f1 - f0
        if hasattr(st, "action_slot") and len(act.slots):
            st.action_slot = act.slots[0]
        tr.mute = False
    arm.animation_data.action = None
    poner_armas(factory, cfg, arm)
    return cfg, arm


def exportar(salida, cid, arm):
    os.makedirs(salida, exist_ok=True)
    ruta = os.path.join(salida, cid.lower() + ".glb")
    bpy.ops.export_scene.gltf(filepath=ruta, export_format="GLB", export_animation_mode="NLA_TRACKS",
                              export_force_sampling=True, export_frame_step=1, export_anim_single_armature=True,
                              export_image_format="JPEG", export_jpeg_quality=85)
    print("hecho", cid, "->", ruta, [t.name for t in arm.animation_data.nla_tracks])


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    factory, salida = args[0], args[1]
    ids = args[2:] or [os.path.splitext(f)[0] for f in sorted(os.listdir(os.path.join(factory, "config/characters"))) if f.endswith(".json")]
    for cid in ids:
        try:
            convertir(factory, salida, cid)
        except Exception as e:
            print("ERROR", cid, e)
