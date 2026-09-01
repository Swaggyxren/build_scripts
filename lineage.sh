#!/bin/bash
set -e

# ==============================================================================
#  LineageOS Build Script for Tecno Pova 5 Pro 5G (LH8n)
# ==============================================================================

echo "=== [1/5] Cleaning existing device and vendor trees ==="
rm -rf device/tecno/LH8n vendor/tecno/LH8n kernel/tecno/LH8n

echo "=== [2/5] Cloning Tecno LH8n Trees ==="
git clone https://github.com/Swaggyxren/android_device_tecno_LH8n.git --depth 1 -b lineage-23.2 device/tecno/LH8n
git clone https://github.com/Swaggyxren/vendor_tecno_LH8n.git --depth 1 -b lineage-23.2 vendor/tecno/LH8n
git clone https://github.com/Swaggyxren/android_kernel_tecno_LH8n.git --depth 1 -b main kernel/tecno/LH8n

echo "=== [3/5] Resyncing Sources ==="
/opt/crave/resync.sh

echo "=== [4/5] Setting Up Build Environment ==="
source build/envsetup.sh
lunch lineage_LH8n-userdebug

echo "=== [5/5] Compiling LineageOS ==="
m bacon
