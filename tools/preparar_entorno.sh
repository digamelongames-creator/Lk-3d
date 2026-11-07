#!/usr/bin/env bash
# Prepara un espacio de trabajo nuevo de Claude para Last Knight 3D (autorizado por Diego):
# Godot 4.7.2 oficial, Vulkan por software (lavapipe) para las capturas y Blender como módulo (bpy).
set -e
if ! command -v godot >/dev/null || ! godot --version | grep -q "4.7.2"; then
	cd /tmp
	curl -sSL -o godot.zip https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip
	unzip -qo godot.zip
	mv Godot_v4.7.2-stable_linux.x86_64 /usr/local/bin/godot
	cd - >/dev/null
fi
if [ ! -f /usr/share/vulkan/icd.d/lvp_icd.json ]; then
	apt-get install -y -q mesa-vulkan-drivers >/dev/null 2>&1 || (apt-get update -q >/dev/null && apt-get install -y -q mesa-vulkan-drivers >/dev/null)
fi
python3 -c "import bpy" 2>/dev/null || pip install -q --break-system-packages bpy
godot --version
echo "Listo. Capturas: VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a godot --path . -- --bot --shot=/tmp/x.png,200"
