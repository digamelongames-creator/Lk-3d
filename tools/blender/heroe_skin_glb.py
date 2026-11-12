"""Personaje riggeado en Mixamo (FBX «With Skin») → .glb con solo la malla y el esqueleto, para vestir a un héroe.

  python3 tools/blender/heroe_skin_glb.py <personaje.fbx> assets/monstruos/<id>.glb

El esqueleto se llama «esqueleto», como en esqueleto.glb, para que las pistas de sus animaciones
(«esqueleto/Skeleton3D:mixamorig_…») valgan tal cual: Modelo3D las copia (ficha «anims_de»).
Se quitan las animaciones que traiga el .fbx (la pose de Mixamo).
"""
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from monstruos_glb import importar_fbx, limpiar  # noqa: E402


def main(fbx, salida):
    limpiar()
    nuevos = importar_fbx(fbx)
    arm = next(o for o in nuevos if o.type == "ARMATURE")
    arm.name = "esqueleto"
    if arm.animation_data:
        arm.animation_data.action = None
    for a in list(bpy.data.actions):
        bpy.data.actions.remove(a)
    for o in nuevos:
        if o.type not in ("ARMATURE", "MESH"):
            bpy.data.objects.remove(o, do_unlink=True)
    bpy.context.view_layer.update()
    # alto en reposo (para la ficha de Modelo3D)
    zs = [(o.matrix_world @ v.co).z for o in bpy.data.objects if o.type == "MESH" for v in o.data.vertices]
    os.makedirs(os.path.dirname(os.path.abspath(salida)), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=salida, export_format="GLB", export_animations=False,
                              export_image_format="AUTO")
    print("hecho:", salida, "alto en reposo: %.3f m" % (max(zs) - min(zs)))


if __name__ == "__main__":
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    main(a[0], a[1])
