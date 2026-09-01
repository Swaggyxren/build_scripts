#!/bin/bash
set -eo pipefail

# ==============================================================================
#  LineageOS Build Script for Tecno Pova 5 Pro 5G (LH8n)
#  Features: Telegram Status Pinger & Automated GoFile Uploader
# ==============================================================================

START_TIME=$(date +%s)
DEVICE="LH8n"
ROM="LineageOS 23.2"

# --- Telegram Notification Helper ---
tg_send_message() {
    local text="$1"
    if [[ -n "${TG_TOKEN}" && -n "${TG_CHAT_ID}" ]]; then
        curl -s -X POST "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
            -d chat_id="${TG_CHAT_ID}" \
            -d parse_mode="HTML" \
            -d disable_web_page_preview="true" \
            -d text="${text}" >/dev/null 2>&1 || true
    fi
}

# --- GoFile Upload Helper ---
upload_to_gofile() {
    local file_path="$1"
    if [[ ! -f "${file_path}" ]]; then
        echo "ERROR: File ${file_path} not found for GoFile upload."
        return 1
    fi

    echo "=== Uploading $(basename "${file_path}") to GoFile ==="
    local server
    server=$(curl -ks "https://api.gofile.io/servers" | jq -r '.data.servers[0].name' 2>/dev/null || echo "")

    if [[ -z "${server}" || "${server}" == "null" ]]; then
        server="store1"
    fi

    local response
    response=$(curl -k -# -F "file=@${file_path}" "https://${server}.gofile.io/contents/uploadfile")
    local download_url
    download_url=$(echo "${response}" | jq -r '.data.downloadPage' 2>/dev/null || echo "")

    if [[ -n "${download_url}" && "${download_url}" != "null" ]]; then
        echo "GoFile Download Link: ${download_url}"
        echo "${download_url}"
    else
        echo "GoFile upload response: ${response}"
    fi
}

# --- Error Handler ---
on_failure() {
    local exit_code=$?
    local failed_line=$1
    local end_time
    end_time=$(date +%s)
    local duration=$(( (end_time - START_TIME) / 60 ))

    local fail_msg="❌ <b>Build Failed!</b>
📱 <b>Device:</b> Tecno Pova 5 Pro (<code>${DEVICE}</code>)
🧬 <b>Target:</b> <code>${ROM}</code>
⚠️ <b>Failed Line:</b> <code>${failed_line}</code> (Exit code: <code>${exit_code}</code>)
⏱️ <b>Duration:</b> ${duration} minutes"

    tg_send_message "${fail_msg}"
    echo "=== Build failed on line ${failed_line} with exit code ${exit_code} ==="
    exit "${exit_code}"
}

trap 'on_failure ${LINENO}' ERR

# --- 1. Send Build Started Notification ---
start_msg="🚀 <b>Build Started!</b>
📱 <b>Device:</b> Tecno Pova 5 Pro (<code>${DEVICE}</code>)
🧬 <b>Target:</b> <code>${ROM}</code>
🌿 <b>Branch:</b> <code>lineage-23.2-test</code>
📅 <b>Started:</b> $(date "+%Y-%m-%d %H:%M:%S UTC")"

tg_send_message "${start_msg}"

echo "=== [1/6] Cleaning previous trees ==="
rm -rf device/tecno/LH8n \
       vendor/tecno/LH8n \
       device/tecno/LH8n-kernel \
       vendor/mediatek/ims \
       device/mediatek/sepolicy_vndr \
       hardware/mediatek \
       vendor/sony/dolby \
       vendor/lineage-priv/keys

echo "=== [2/6] Cloning Device, Vendor, Kernel & Dependencies ==="
git clone https://github.com/Swaggyxren/android_device_tecno_LH8n.git --depth 1 -b lineage-23.2-test device/tecno/LH8n
git clone https://github.com/Swaggyxren/vendor_tecno_LH8n.git --depth 1 -b vendor-test vendor/tecno/LH8n
git clone https://github.com/Swaggyxren/android_kernel_tecno_LH8n.git --depth 1 -b test device/tecno/LH8n-kernel
git clone https://github.com/techyminati/android_vendor_mediatek_ims --depth 1 vendor/mediatek/ims
git clone https://github.com/crdroidandroid/android_device_mediatek_sepolicy_vndr --depth 1 device/mediatek/sepolicy_vndr
git clone https://github.com/crdroidandroid/android_hardware_mediatek.git --depth 1 -b 16.0 hardware/mediatek
git clone https://github.com/naden01/android_vendor_sony_dolby --depth 1 vendor/sony/dolby
git clone https://gitlab.com/naden01/keys-los23.git --depth 1 vendor/lineage-priv/keys

echo "=== [3/6] Resyncing Sources ==="
/opt/crave/resync.sh

echo "=== [4/6] Setting Up Build Environment ==="
source build/envsetup.sh
lunch lineage_LH8n-userdebug

echo "=== [5/6] Compiling LineageOS ==="
m bacon

echo "=== [6/6] Packaging & Uploading Artifacts ==="
END_TIME=$(date +%s)
DURATION=$(( (END_TIME - START_TIME) / 60 ))

OUT_DIR="out/target/product/${DEVICE}"
ZIP_PATH=$(find "${OUT_DIR}" -maxdepth 1 -name "lineage-*.zip" | head -n 1)

if [[ -f "${ZIP_PATH}" ]]; then
    ZIP_NAME=$(basename "${ZIP_PATH}")
    ZIP_SIZE=$(du -h "${ZIP_PATH}" | awk '{print $1}')
    
    echo "Uploading ${ZIP_NAME} (${ZIP_SIZE}) to GoFile..."
    GOFILE_URL=$(upload_to_gofile "${ZIP_PATH}" | tail -n 1)

    success_msg="✅ <b>Build Succeeded!</b>
📱 <b>Device:</b> Tecno Pova 5 Pro (<code>${DEVICE}</code>)
🧬 <b>Target:</b> <code>${ROM}</code>
📦 <b>Filename:</b> <code>${ZIP_NAME}</code>
📊 <b>Size:</b> <code>${ZIP_SIZE}</code>
⏱️ <b>Build Time:</b> ${DURATION} minutes
🔗 <b>Download:</b> <a href=\"${GOFILE_URL}\">GoFile Link</a>"

    tg_send_message "${success_msg}"
else
    no_zip_msg="⚠️ <b>Build Finished, but no ROM .zip was found in output folder!</b>
📱 <b>Device:</b> <code>${DEVICE}</code>
⏱️ <b>Time:</b> ${DURATION} minutes"
    tg_send_message "${no_zip_msg}"
fi

echo "=== Build & Upload Workflow Completed in ${DURATION} minutes ==="
