"""Corta un set de armadura de Tripo (una sola malla con todas las piezas en fila) en piezas sueltas.

Uso:  python3 tools/blender/armadura_set.py <set.glb> <carpeta de salida> [set]
      python3 tools/blender/armadura_set.py tools/armaduras/caballero_oscuro.glb assets/armaduras/caballero_oscuro

Cada pieza sale en su .gltf, y centros.json guarda dónde estaba el centro de cada una en el original (texturas compartidas en la misma carpeta), con el origen en el centro de su
caja y los ejes del archivo original: +Y arriba, +Z delante y −X a la derecha del personaje.
Las reglas de cada set (en coordenadas glTF del archivo de Tripo, en metros) van en SETS: cada cara va a
la primera pieza cuya regla cumpla su centro.
"""
import sys
import os
import json
import bpy
import bmesh


def caballero_oscuro(x, y, z):
    """Set del Caballero Oscuro (armadura.glb de Diego): espada, peto, casco, guantes, botas, cinturón, escudo"""
    if x < -0.383:
        return "espada"
    if x < -0.197:
        # hombreras: lo que sobresale a los lados del peto por encima de los hombros
        if y > 0.150 and x < -0.287 - 0.042:
            return "hombrera_der"
        if y > 0.150 and x > -0.287 + 0.042:
            return "hombrera_izq"
        return "peto"
    if x < -0.090:
        return "casco"
    if x < -0.026:
        return "guante_der"
    if x < 0.031:
        return "guante_izq"
    if x < 0.109:
        return "bota_der_cana" if y > 0.105 else "bota_der_pie"
    if x < 0.180:
        return "bota_izq_cana" if y > 0.105 else "bota_izq_pie"
    if x < 0.330:
        return "cinturon"
    return "escudo"


SETS = {"caballero_oscuro": caballero_oscuro}


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    origen, salida = args[0], args[1]
    regla = SETS[args[2] if len(args) > 2 else "caballero_oscuro"]
    os.makedirs(salida, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.abspath(origen))
    mallas = [o for o in bpy.data.objects if o.type == "MESH"]
    for o in mallas:
        o.select_set(True)
    bpy.context.view_layer.objects.active = mallas[0]
    if len(mallas) > 1:
        bpy.ops.object.join()
    base = bpy.context.view_layer.objects.active
    mw = base.matrix_world.copy()
    base.parent = None
    base.matrix_world = mw
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    # Blender (Z arriba) → glTF (Y arriba): x = x, y = z, z = −y
    bm = bmesh.new()
    bm.from_mesh(base.data)
    clases = {}
    for f in bm.faces:
        c = f.calc_center_median()
        clases.setdefault(regla(c.x, c.z, -c.y), []).append(f.index)
    bm.free()
    print("piezas:", {k: len(v) for k, v in clases.items()})
    centros = {}
    for nombre, caras in sorted(clases.items()):
        bpy.ops.object.select_all(action="DESELECT")
        o = base.copy()
        o.data = base.data.copy()
        o.name = nombre
        bpy.context.collection.objects.link(o)
        bm = bmesh.new()
        bm.from_mesh(o.data)
        quedan = set(caras)
        bm.faces.ensure_lookup_table()
        bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.index not in quedan], context="FACES")
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
        bm.to_mesh(o.data)
        bm.free()
        o.select_set(True)
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.origin_set(type="ORIGIN_GEOMETRY", center="BOUNDS")
        c = o.location
        centros[nombre] = [round(c.x, 4), round(c.z, 4), round(-c.y, 4)]   # en coordenadas glTF del original
        o.location = (0, 0, 0)
        bpy.ops.export_scene.gltf(filepath=os.path.join(os.path.abspath(salida), nombre + ".gltf"),
                                  export_format="GLTF_SEPARATE", use_selection=True, export_yup=True,
                                  export_animations=False)
        bpy.data.objects.remove(o, do_unlink=True)
    # centro de cada pieza en el archivo original: Armadura3D coloca las piezas con sus anclas (puntos del original)
    with open(os.path.join(salida, "centros.json"), "w") as f:
        json.dump(centros, f, indent=1, sort_keys=True)


main()
