"""Panel «Agarre» de Blender para colocar a ojo las armas en las manos de un personaje de SPRITE_FACTORY.

Lo abre colocar_arma.bat:  blender --python colocar_arma.py -- <carpeta SPRITE_FACTORY> <id del personaje>

Monta el personaje con sus animaciones, como el conversor, y en la barra lateral (N), pestaña «Agarre»:
  - Mano (derecha o izquierda), Objeto (espada o escudo) y Arma (el archivo).
  - Animación: para ver el agarre en movimiento (moviendo la línea de tiempo).
  - «Espejar desde la derecha»: pone en la izquierda la espada de la derecha reflejada.
  - «Guardar agarre»: lo escribe en la ficha del personaje (config/characters/<id>.json, «agarres_3d»).
El arma se mueve (G), se gira (R) y se escala (S) como cualquier objeto; va pegada al hueso de la mano.
"""
import bpy
import json
import os
import sys
from mathutils import Matrix

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import agarre as AG  # noqa: E402
import monstruos_glb as MG  # noqa: E402

PALABRAS = ("weapon", "arma", "sword", "espada", "shield", "escudo", "dagger", "daga", "axe", "hacha", "mace", "maza", "spear", "lanza")
EST = {"factory": "", "cid": "", "ficha": "", "cfg": {}, "arm": None, "armas": []}
MANO_N = {"main_hand": "Derecha", "off_hand": "Izquierda"}


def buscar_armas(factory, cfg):
    vistas = []
    for l in cfg.get("loadout", {}).values():
        vistas.append(l["file"])
    for m in cfg.get("agarres_3d", {}).values():
        for a in m.values():
            vistas.append(a["file"])
    for raiz, dirs, fich in os.walk(factory):
        rel = os.path.relpath(raiz, factory)
        if rel.count(os.sep) > 4 or any(x in rel.lower() for x in ("output", "render", "sprites", ".git")):
            dirs[:] = []
            continue
        for f in fich:
            r = os.path.join(rel, f).replace("\\", "/").lstrip("./")
            if f.lower().endswith((".glb", ".gltf", ".fbx")) and any(p in r.lower() for p in PALABRAS):
                vistas.append(r)
    res = []
    for v in vistas:
        v = v.replace("\\", "/")
        if v not in res:
            res.append(v)
    return res


def nombre_obj(mano):
    return "colocar_" + mano


def quitar(mano):
    o = bpy.data.objects.get(nombre_obj(mano))
    if o is not None:
        bpy.data.objects.remove(o, do_unlink=True)


def por_defecto(obj, tipo):
    """sin agarre guardado: el arma en la palma, a un tamaño razonable, para empezar a ajustar"""
    largo = max(max(obj.dimensions), 1e-6)
    k = (1.0 if tipo == "espada" else .6) / largo
    return Matrix.Translation((0, .08, 0)) @ Matrix.Scale(k, 4)


def cargar(mano, tipo, fichero, m=None):
    arm = EST["arm"]
    quitar(mano)
    obj = AG.cargar_arma(os.path.join(EST["factory"], fichero), nombre_obj(mano))
    if obj is None:
        return None
    obj["fichero"] = fichero
    obj["tipo"] = tipo
    if m is None:
        a = AG.leer(EST["cfg"], mano, tipo)
        if a is not None and a["file"] == fichero:
            m = AG.de_lista(a["m"])
    if m is None and mano == "off_hand" and tipo == "espada":
        a = AG.leer(EST["cfg"], "main_hand", "espada")
        if a is not None and a["file"] == fichero:
            m = AG.espejo(arm, AG.de_lista(a["m"]))
    if m is None:
        m = por_defecto(obj, tipo)
    AG.poner(arm, mano, obj, m)
    seleccionar(obj)
    return obj


def seleccionar(obj):
    bpy.ops.object.mode_set(mode="OBJECT") if bpy.context.object and bpy.context.object.mode != "OBJECT" else None
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


# ---------------------------------------------------------------- propiedades


def _armas(self, context):
    return [(f, os.path.basename(f), f) for f in EST["armas"]] or [("", "(no hay armas)", "")]


def _anims(self, context):
    arm = EST["arm"]
    if arm is None or arm.animation_data is None:
        return [("", "(ninguna)", "")]
    return [(t.name, t.name, "") for t in arm.animation_data.nla_tracks]


def _al_cambiar(self, context):
    s = context.scene
    if s.agarre_arma:
        cargar(s.agarre_mano, s.agarre_tipo, s.agarre_arma)


def _al_cambiar_anim(self, context):
    arm = EST["arm"]
    for t in arm.animation_data.nla_tracks:
        t.mute = t.name != context.scene.agarre_anim
        if t.name == context.scene.agarre_anim and len(t.strips):
            context.scene.frame_start = int(t.strips[0].frame_start)
            context.scene.frame_end = int(t.strips[0].frame_end)
    context.scene.frame_set(context.scene.frame_start)


def registrar_props():
    S = bpy.types.Scene
    S.agarre_mano = bpy.props.EnumProperty(name="Mano", items=[("main_hand", "Derecha", ""), ("off_hand", "Izquierda", "")], update=_al_cambiar)
    S.agarre_tipo = bpy.props.EnumProperty(name="Objeto", items=[("espada", "Espada", ""), ("escudo", "Escudo", "")], update=_al_cambiar)
    S.agarre_arma = bpy.props.EnumProperty(name="Arma", items=_armas, update=_al_cambiar)
    S.agarre_anim = bpy.props.EnumProperty(name="Animación", items=_anims, update=_al_cambiar_anim)


# ---------------------------------------------------------------- botones


class AGARRE_OT_guardar(bpy.types.Operator):
    bl_idname = "agarre.guardar"
    bl_label = "Guardar agarre"
    bl_description = "Escribe la posición del arma de esta mano en la ficha del personaje"

    def execute(self, context):
        s = context.scene
        obj = bpy.data.objects.get(nombre_obj(s.agarre_mano))
        if obj is None:
            self.report({"ERROR"}, "No hay arma en esa mano")
            return {"CANCELLED"}
        m = AG.medir(EST["arm"], s.agarre_mano, obj)
        EST["cfg"] = AG.guardar(EST["ficha"], s.agarre_mano, s.agarre_tipo, obj["fichero"], m)
        self.report({"INFO"}, "Guardado: %s, %s, %s" % (MANO_N[s.agarre_mano], s.agarre_tipo, os.path.basename(obj["fichero"])))
        return {"FINISHED"}


class AGARRE_OT_espejar(bpy.types.Operator):
    bl_idname = "agarre.espejar"
    bl_label = "Espejar desde la derecha"
    bl_description = "Pone en la mano izquierda el arma de la derecha, reflejada"

    def execute(self, context):
        s = context.scene
        der = bpy.data.objects.get(nombre_obj("main_hand"))
        if der is None:
            self.report({"ERROR"}, "Primero pon un arma en la mano derecha")
            return {"CANCELLED"}
        m = AG.espejo(EST["arm"], AG.medir(EST["arm"], "main_hand", der))
        cargar("off_hand", der["tipo"], der["fichero"], m)
        s["agarre_mano"] = 1   # sin disparar la recarga
        return {"FINISHED"}


class AGARRE_OT_otra(bpy.types.Operator):
    bl_idname = "agarre.otra"
    bl_label = "Otro archivo…"
    bl_description = "Elegir un arma (.glb o .fbx) que no esté en la lista"
    filepath: bpy.props.StringProperty(subtype="FILE_PATH")
    filter_glob: bpy.props.StringProperty(default="*.glb;*.gltf;*.fbx", options={"HIDDEN"})

    def invoke(self, context, event):
        self.filepath = EST["factory"] + os.sep
        context.window_manager.fileselect_add(self)
        return {"RUNNING_MODAL"}

    def execute(self, context):
        try:
            rel = os.path.relpath(self.filepath, EST["factory"]).replace("\\", "/")
        except ValueError:
            self.report({"ERROR"}, "El arma tiene que estar dentro de SPRITE_FACTORY")
            return {"CANCELLED"}
        if rel.startswith(".."):
            self.report({"ERROR"}, "El arma tiene que estar dentro de SPRITE_FACTORY")
            return {"CANCELLED"}
        if rel not in EST["armas"]:
            EST["armas"].append(rel)
        context.scene.agarre_arma = rel
        return {"FINISHED"}


class AGARRE_PT_panel(bpy.types.Panel):
    bl_label = "Agarre"
    bl_space_type = "VIEW_3D"
    bl_region_type = "UI"
    bl_category = "Agarre"

    def draw(self, context):
        s = context.scene
        c = self.layout.column()
        c.label(text="Personaje: " + EST["cid"])
        c.prop(s, "agarre_mano")
        c.prop(s, "agarre_tipo")
        c.prop(s, "agarre_arma")
        c.operator("agarre.otra")
        c.separator()
        c.prop(s, "agarre_anim")
        c.label(text="Mueve la línea de tiempo para ver el agarre")
        c.separator()
        c.operator("agarre.espejar")
        c.separator()
        c.scale_y = 1.4
        c.operator("agarre.guardar", icon="FILE_TICK")


CLASES = (AGARRE_OT_guardar, AGARRE_OT_espejar, AGARRE_OT_otra, AGARRE_PT_panel)


def preparar_vista():
    """barra lateral abierta en «Agarre» y la vista centrada en la mano derecha"""
    for win in bpy.context.window_manager.windows:
        for area in win.screen.areas:
            if area.type != "VIEW_3D":
                continue
            sp = area.spaces.active
            sp.show_region_ui = True
            sp.shading.type = "MATERIAL"
            reg = next(r for r in area.regions if r.type == "WINDOW")
            with bpy.context.temp_override(window=win, area=area, region=reg):
                try:
                    bpy.ops.view3d.view_selected()
                except RuntimeError:
                    pass
            for r in area.regions:
                if r.type == "UI":
                    try:
                        r.active_panel_category = "Agarre"
                    except (AttributeError, TypeError):
                        pass
    return None


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if len(args) < 2:
        print("Uso: blender --python colocar_arma.py -- <SPRITE_FACTORY> <id>")
        return
    factory, cid = os.path.abspath(args[0]), args[1]
    EST["factory"], EST["cid"] = factory, cid
    EST["ficha"] = os.path.join(factory, "config/characters", cid + ".json")
    cfg, arm = MG.montar(factory, cid)
    EST["cfg"], EST["arm"] = cfg, arm
    # lo que pone el conversor se quita: aquí se coloca a mano
    for o in list(bpy.data.objects):
        if o.name.startswith(("arma_", "agarre_")):
            bpy.data.objects.remove(o, do_unlink=True)
    EST["armas"] = buscar_armas(factory, cfg)
    for c in CLASES:
        bpy.utils.register_class(c)
    registrar_props()
    s = bpy.context.scene
    if arm.animation_data and len(arm.animation_data.nla_tracks):
        nombres = [t.name for t in arm.animation_data.nla_tracks]
        s.agarre_anim = "idle" if "idle" in nombres else nombres[0]
    # lo que ya tenga guardado: las dos manos a la vista
    for mano in AG.MANOS:
        for tipo in AG.TIPOS:
            a = AG.leer(cfg, mano, tipo)
            if a is not None and bpy.data.objects.get(nombre_obj(mano)) is None:
                cargar(mano, tipo, a["file"], AG.de_lista(a["m"]))
    if bpy.data.objects.get(nombre_obj("main_hand")) is None:
        l = next((l for l in cfg.get("loadout", {}).values() if l["slot"] == "main_hand"), None)
        f = l["file"] if l else (EST["armas"][0] if EST["armas"] else None)
        if f:
            cargar("main_hand", AG.tipo_de(f), f)
    obj = bpy.data.objects.get(nombre_obj("main_hand")) or bpy.data.objects.get(nombre_obj("off_hand"))
    if obj is not None:
        seleccionar(obj)
        s["agarre_tipo"] = AG.TIPOS.index(obj["tipo"])
        if obj["fichero"] in EST["armas"]:
            s["agarre_arma"] = EST["armas"].index(obj["fichero"])
    if not bpy.app.background:
        bpy.app.timers.register(preparar_vista, first_interval=.5)
    print("Agarre listo:", cid, "armas:", EST["armas"])


main()
