#!/bin/bash
set -e

# ==============================================================================
#  YAAP 17 Build Script for Tecno Pova 5 Pro 5G (LH8n)
#  Target: YAAP (Android 15 / 16)
# ==============================================================================

echo "=== [1/6] Cleaning existing device and vendor trees ==="
rm -rf device/tecno/LH8n vendor/tecno/LH8n kernel/tecno/LH8n .repo/local_manifests

echo "=== [2/6] Initializing YAAP Manifest ==="
repo init -u https://github.com/yaap/manifest.git -b fifteen --git-lfs --depth=1

echo "=== [3/6] Cloning Tecno LH8n Trees ==="
git clone https://github.com/Swaggyxren/android_device_tecno_LH8n.git --depth 1 -b yaap-17 device/tecno/LH8n
git clone https://github.com/Swaggyxren/vendor_tecno_LH8n.git --depth 1 -b yaap-17 vendor/tecno/LH8n
git clone https://github.com/Swaggyxren/android_kernel_tecno_LH8n.git --depth 1 -b main kernel/tecno/LH8n

echo "=== [4/6] Resyncing Sources ==="
/opt/crave/resync.sh

echo "=== [5/6] Setting Up Build Environment ==="
source build/envsetup.sh
lunch yaap_LH8n-userdebug

echo "=== [6/6] Compiling YAAP ==="
m yaap
