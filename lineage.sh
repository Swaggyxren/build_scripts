#!/bin/bash
set -e

# ==============================================================================
#  LineageOS Build Script for Tecno Pova 5 Pro 5G (LH8n)
# ==============================================================================

echo "=== [1/5] Cleaning previous trees ==="
rm -rf device/tecno/LH8n \
       vendor/tecno/LH8n \
       device/tecno/LH8n-kernel \
       vendor/mediatek/ims \
       device/mediatek/sepolicy_vndr \
       hardware/mediatek \
       vendor/sony/dolby \
       vendor/lineage-priv/keys

echo "=== [2/5] Cloning Device, Vendor, Kernel & Dependencies ==="
git clone https://github.com/Swaggyxren/android_device_tecno_LH8n.git --depth 1 -b los-test device/tecno/LH8n
git clone https://github.com/Swaggyxren/vendor_tecno_LH8n.git --depth 1 -b vendor-test vendor/tecno/LH8n
git clone https://github.com/Swaggyxren/android_kernel_tecno_LH8n.git --depth 1 -b test device/tecno/LH8n-kernel
git clone https://github.com/techyminati/android_vendor_mediatek_ims --depth 1 vendor/mediatek/ims
git clone https://github.com/crdroidandroid/android_device_mediatek_sepolicy_vndr --depth 1 device/mediatek/sepolicy_vndr
git clone https://github.com/crdroidandroid/android_hardware_mediatek.git --depth 1 -b 16.0 hardware/mediatek
git clone https://github.com/naden01/android_vendor_sony_dolby --depth 1 vendor/sony/dolby
git clone https://gitlab.com/naden01/keys-los23.git --depth 1 vendor/lineage-priv/keys

echo "=== [3/5] Resyncing Sources ==="
/opt/crave/resync.sh

echo "=== [4/5] Setting Up Build Environment ==="
source build/envsetup.sh
lunch lineage_LH8n-userdebug

echo "=== [5/5] Compiling LineageOS ==="
m bacon
