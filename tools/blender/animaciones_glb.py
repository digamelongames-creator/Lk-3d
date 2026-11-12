"""Animaciones de Mixamo sueltas (FBX «Without Skin») para el héroe → assets/monstruos/heroe_anims.glb
y assets/monstruos/heroe_anims.json (duración y momento del golpe de cada una).

  python3 tools/blender/animaciones_glb.py <carpeta con los .fbx>

Los nombres de los archivos de Diego (C:\\Carpeta Juego\\animaciones) se pasan a los del juego con NOMBRES.
El esqueleto se llama «esqueleto», como en esqueleto.glb, para que las pistas sean las mismas
(«esqueleto/Skeleton3D:mixamorig_…») y Modelo3D.anadir_animaciones() las pueda copiar al héroe.
Se quita el avance de la cadera en horizontal (el héroe no avanza al atacar).
El golpe: el fotograma en que la mano derecha va más rápida (como el tajo del esqueleto), en fracción del clip.
"""
import json
import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(__file__))
from monstruos_glb import accion_de, limpiar, importar_fbx  # noqa: E402

# empieza por (minúsculas, sin espacios dobles) → nombre en el juego
NOMBRES = [
    ("cast burst", "lanzar_estallido"),     # el resto de habilidades del mago
    ("cast fireball", "lanzar_bola"),       # bola de fuego del mago
    ("cast major", "lanzar_mayor"),         # levantar muertos
    ("cast minor", "lanzar_menor"),         # habilidades de los caballeros
    ("sword and shield jump attack", "ataque_salto"),
    ("sword and shield attack combo", "combo_ataque"),
    ("sword and shield slashcombo", "combo_tajos"),
    ("sword and shield ihurt", "dolor_escudo"),
    ("sword and shield hurt", "dolor_escudo"),
    ("sword and shield walk", "andar"),     # andar de todos los héroes (en lugar de run)
]
BUCLES = {"andar"}   # las que se repiten: además de duración y golpe, guardan «avance» (m/s del clip)


def nombre_de(fich):
    base = " ".join(os.path.splitext(fich)[0].lower().split())
    for ini, n in NOMBRES:
        if base.startswith(ini):
            return n
    return None


def golpe(arm, act, f0, f1):
    """fracción del clip en que la mano derecha va más rápida"""
    arm.animation_data.action = act
    if hasattr(arm.animation_data, "action_slot") and len(act.slots):
        arm.animation_data.action_slot = act.slots[0]
    pb = arm.pose.bones.get("mixamorig:RightHand")
    if pb is None:
        return .5
    antes, mejor, cuando = None, -1.0, f0
    for f in range(int(f0), int(f1) + 1):
        bpy.context.scene.frame_set(f)
        p = arm.matrix_world @ pb.head
        if antes is not None and (p - antes).length > mejor:
            mejor, cuando = (p - antes).length, f
        antes = Vector(p)
    arm.animation_data.action = None
    return (cuando - f0) / max(1, f1 - f0)


def avance(ruta):
    """metros por segundo que avanza la cadera en el clip original (antes de quitarle el avance)"""
    nuevos = importar_fbx(ruta)
    arm = next(o for o in nuevos if o.type == "ARMATURE")
    act = arm.animation_data.action
    f0, f1 = act.frame_range
    pb = arm.pose.bones["mixamorig:Hips"]
    bpy.context.scene.frame_set(int(f0))
    p0 = arm.matrix_world @ pb.head
    bpy.context.scene.frame_set(int(f1))
    p1 = arm.matrix_world @ pb.head
    d = p1 - p0
    v = Vector((d.x, d.y)).length / max(1e-3, (f1 - f0) / bpy.context.scene.render.fps)
    for o in nuevos:
        bpy.data.objects.remove(o, do_unlink=True)
    bpy.data.actions.remove(act)
    return round(v, 3)


def main(carpeta, salida):
    limpiar()
    fbx = sorted(f for f in os.listdir(carpeta) if f.lower().endswith(".fbx") and nombre_de(f))
    if not fbx:
        print("no hay .fbx conocidos en", carpeta)
        return
    # el esqueleto: el del primer archivo
    nuevos = importar_fbx(os.path.join(carpeta, fbx[0]))
    arm = next(o for o in nuevos if o.type == "ARMATURE")
    for o in nuevos:
        if o is not arm:
            bpy.data.objects.remove(o, do_unlink=True)
    arm.name = "esqueleto"
    if arm.animation_data and arm.animation_data.action:
        bpy.data.actions.remove(arm.animation_data.action)
    if arm.animation_data is None:
        arm.animation_data_create()
    datos = {}
    fps = bpy.context.scene.render.fps
    for f in fbx:
        n = nombre_de(f)
        if n in datos:
            continue
        v = avance(os.path.join(carpeta, f)) if n in BUCLES else None
        act = accion_de(os.path.join(carpeta, f), n, None, True)
        f0, f1 = act.frame_range
        datos[n] = {"archivo": f, "duracion": round((f1 - f0) / fps, 3), "golpe": round(golpe(arm, act, f0, f1), 3)}
        if v is not None:
            datos[n]["avance"] = v
        tr = arm.animation_data.nla_tracks.new()
        tr.name = n
        st = tr.strips.new(n, int(f0), act)
        if hasattr(st, "action_slot") and len(act.slots):
            st.action_slot = act.slots[0]
        print(f"  {f} → {n}  {datos[n]}")
    arm.animation_data.action = None
    os.makedirs(salida, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(salida, "heroe_anims.glb"), export_format="GLB",
                              export_animation_mode="NLA_TRACKS", export_force_sampling=True, export_frame_step=1,
                              export_anim_single_armature=True)
    with open(os.path.join(salida, "heroe_anims.json"), "w", encoding="utf-8") as fh:
        json.dump(datos, fh, ensure_ascii=False, indent=1)
    print("hecho:", os.path.join(salida, "heroe_anims.glb"), list(datos))


if __name__ == "__main__":
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    main(a[0], a[1] if len(a) > 1 else os.path.join(os.path.dirname(__file__), "..", "..", "assets", "monstruos"))
