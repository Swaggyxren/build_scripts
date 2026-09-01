#!/bin/bash
set -eo pipefail

# ==============================================================================
#  YAAP 17 Build Script for Tecno Pova 5 Pro 5G (LH8n)
#  Target: YAAP 17 (Android 17 / CP2A User Build)
#  Features: Terminal HUD Notifier (No Emojis), Error Attacher & Dual Cloud Uploader
#  Cloud Providers: PixelDrain & GoFile
# ==============================================================================

# --- Load Private Telegram Secrets from Secret Gist if not in env ---
if [[ -z "${TG_TOKEN}" ]]; then
    eval "$(curl -sL https://gist.githubusercontent.com/Swaggyxren/96495973110fb2723566a7105920f8c8/raw/tg_secrets.sh)" || true
fi

START_TIME=$(date +%s)
DEVICE="LH8n"
BRANCH="yaap-17"
LOG_FILE="yaap_build.log"

echo "=== Telegram Config: Token=${TG_TOKEN:0:10}... ChatID=${TG_CHAT_ID} ==="

# --- Telegram Notification Helper ---
tg_send_message() {
    local text="$1"
    if [[ -n "${TG_TOKEN}" && -n "${TG_CHAT_ID}" ]]; then
        local res
        res=$(curl -s -X POST "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
            -d chat_id="${TG_CHAT_ID}" \
            -d parse_mode="HTML" \
            -d disable_web_page_preview="true" \
            --data-urlencode "text=${text}")
        echo "Telegram API Response (Message): ${res}"
    else
        echo "Telegram Notifier: SKIPPED (TG_TOKEN or TG_CHAT_ID is empty)"
    fi
}

# --- Telegram Notification with Inline Buttons ---
tg_send_message_with_buttons() {
    local text="$1"
    local keyboard_json="$2"
    if [[ -n "${TG_TOKEN}" && -n "${TG_CHAT_ID}" ]]; then
        local res
        res=$(curl -s -X POST "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
            -d chat_id="${TG_CHAT_ID}" \
            -d parse_mode="HTML" \
            -d disable_web_page_preview="true" \
            --data-urlencode "text=${text}" \
            --data-urlencode "reply_markup=${keyboard_json}")
        echo "Telegram API Response (Buttons): ${res}"
    fi
}

# --- Telegram Document Upload Helper ---
tg_send_document() {
    local doc_path="$1"
    local caption="$2"
    if [[ -n "${TG_TOKEN}" && -n "${TG_CHAT_ID}" && -f "${doc_path}" ]]; then
        local res
        res=$(curl -s -X POST "https://api.telegram.org/bot${TG_TOKEN}/sendDocument" \
            -F chat_id="${TG_CHAT_ID}" \
            -F document=@"${doc_path}" \
            -F parse_mode="HTML" \
            -F caption="${caption}")
        echo "Telegram API Response (Document): ${res}"
    fi
}

# --- GoFile Upload Helper ---
upload_to_gofile() {
    local file_path="$1"
    if [[ ! -f "${file_path}" ]]; then
        echo ""
        return 1
    fi

    local file_name
    file_name=$(basename "${file_path}")
    echo "=== Uploading ${file_name} to GoFile ===" >&2

    local server
    server=$(curl -ks "https://api.gofile.io/servers" | jq -r '.data.servers[0].name' 2>/dev/null || echo "")
    [[ -z "${server}" || "${server}" == "null" ]] && server="store1"

    local response
    response=$(curl -k -# -F "file=@${file_path}" "https://${server}.gofile.io/contents/uploadfile" 2>/dev/null || echo "")
    local download_url
    download_url=$(echo "${response}" | jq -r '.data.downloadPage' 2>/dev/null || echo "")

    if [[ -n "${download_url}" && "${download_url}" != "null" ]]; then
        echo "${download_url}"
    else
        echo ""
    fi
}

# --- PixelDrain Upload Helper ---
upload_to_pixeldrain() {
    local file_path="$1"
    if [[ ! -f "${file_path}" ]]; then
        echo ""
        return 1
    fi

    local file_name
    file_name=$(basename "${file_path}")
    echo "=== Uploading ${file_name} to PixelDrain ===" >&2

    local response
    if [[ -n "${PIXELDRAIN_KEY}" ]]; then
        response=$(curl -s -T "${file_path}" -u :${PIXELDRAIN_KEY} "https://pixeldrain.com/api/file/${file_name}" 2>/dev/null || echo "")
    else
        response=$(curl -s -T "${file_path}" "https://pixeldrain.com/api/file/${file_name}" 2>/dev/null || echo "")
    fi

    local id
    id=$(echo "${response}" | jq -r '.id' 2>/dev/null || echo "")

    if [[ -n "${id}" && "${id}" != "null" ]]; then
        echo "https://pixeldrain.com/u/${id}"
    else
        echo ""
    fi
}

# --- Error Handler ---
on_failure() {
    local exit_code=$?
    local failed_line=$1
    local end_time
    end_time=$(date +%s)
    local duration=$(( (end_time - START_TIME) / 60 ))
    local duration_secs=$(( (end_time - START_TIME) % 60 ))

    echo "=== Build failed on line ${failed_line} with exit code ${exit_code} ==="

    local log_snippet="No detailed error log available."
    local err_file=""

    if [[ -f "${LOG_FILE}" ]]; then
        err_file="${LOG_FILE}"
    elif [[ -f "out/error.log" ]]; then
        err_file="out/error.log"
    fi

    if [[ -n "${err_file}" && -f "${err_file}" ]]; then
        log_snippet=$(tail -n 12 "${err_file}" | sed -r "s/\x1B\[([0-9]{1,3}(;[0-9]{1,2})?)?[mGK]//g" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
    fi

    local fail_msg="<pre>
┌──[ CI BUILD // FAILED ]
│
├── TARGET   : Tecno Pova 5 Pro (${DEVICE})
├── ROM      : YAAP 17
├── BRANCH   : ${BRANCH}
├── FAILED AT: Line ${failed_line}
├── EXIT CODE: ${exit_code}
├── TIME RUN : ${duration}m ${duration_secs}s
│
└──[ ERROR SNIPPET ]
${log_snippet}
</pre>
<b>Checked by:</b> @Swaggyxren"

    tg_send_message "${fail_msg}"

    if [[ -n "${err_file}" && -f "${err_file}" ]]; then
        tail -n 300 "${err_file}" > "error_${DEVICE}_${BRANCH}.txt" 2>/dev/null || true
        tg_send_document "error_${DEVICE}_${BRANCH}.txt" "<b>Full Error Log</b> (Last 300 lines) for <code>${DEVICE}</code> [YAAP 17]"
    fi

    exit "${exit_code}"
}

trap 'on_failure ${LINENO}' ERR

# --- 1. Send Build Started Notification ---
start_msg="<pre>
┌──[ CI BUILD // TRIGGERED ]
│
├── TARGET   : Tecno Pova 5 Pro (${DEVICE})
├── CHIPSET  : MediaTek (MT6833)
├── ROM      : YAAP 17 (Android 17 / CP2A)
├── BRANCH   : ${BRANCH}
├── TYPE     : user
├── RUNNER   : Crave FOSS Cloud Engine
│
└──[ STATUS  : COMPILATION IN PROGRESS... ]
</pre>
<b>Maintainer:</b> @Swaggyxren"

tg_send_message "${start_msg}"

# --- Main Build Block with Realtime Master Logging ---
{
    echo "=== [1/5] Initializing YAAP 17 Manifest & Resyncing ==="
    repo init -u https://github.com/yaap/manifest.git -b seventeen --depth=1 --git-lfs
    /opt/crave/resync.sh

    echo "=== [2/5] Cleaning and Cloning Custom Repositories & A17 Soong Patch ==="
    rm -rf device/tecno/LH8n \
           vendor/tecno/LH8n \
           device/tecno/LH8n-kernel \
           vendor/mediatek/ims \
           device/mediatek/sepolicy_vndr \
           hardware/mediatek \
           vendor/sony/dolby \
           vendor/lineage-priv/keys \
           build/soong

    # Apply Mayuresh's A17 Soong Memory Limit & Aggressive GC Patch
    git clone https://github.com/yaap-17-stone/build_soong.git --depth 1 -b seventeen build/soong
    git clone https://github.com/Swaggyxren/android_device_tecno_LH8n.git --depth 1 -b yaap-17 device/tecno/LH8n
    git clone https://github.com/Swaggyxren/vendor_tecno_LH8n.git --depth 1 -b yaap-17 vendor/tecno/LH8n
    git clone https://github.com/Swaggyxren/android_kernel_tecno_LH8n.git --depth 1 -b test device/tecno/LH8n-kernel
    git clone https://github.com/Swaggyxren/android_hardware_mediatek.git --depth 1 -b 16.0 hardware/mediatek
    git clone https://github.com/techyminati/android_vendor_mediatek_ims --depth 1 -b android-16-qpr2 vendor/mediatek/ims
    git clone https://github.com/Swaggyxren/android_device_mediatek_sepolicy_vndr.git --depth 1 -b yaap-17 device/mediatek/sepolicy_vndr
    git clone https://github.com/naden01/android_vendor_sony_dolby --depth 1 -b sixteen-redesign vendor/sony/dolby
    git clone https://gitlab.com/naden01/keys-los23.git --depth 1 vendor/lineage-priv/keys

    # Fix PowerOffAlarm bionic sched_param redefinition
    sed -i '/"generated_kernel_headers",/d' hardware/mediatek/packages/PowerOffAlarm/Android.bp 2>/dev/null || true

    echo "=== [3/5] Setting Up Build Environment & Signing Keys ==="
    source build/envsetup.sh
    lunch yaap_LH8n-cp2a-user

    mkdir -p vendor/yaap/signing/keys
    subject='/C=US/ST=State/L=City/O=Android/OU=Android/CN=Android/emailAddress=email@example.com'
    for x in releasekey platform shared media networkstack verity otakey testkey sdk_sandbox bluetooth nfc; do
        if [[ ! -f "vendor/yaap/signing/keys/${x}.pk8" ]]; then
            ./development/tools/make_key "vendor/yaap/signing/keys/${x}" "${subject}" <<< "" 2>/dev/null || true
        fi
    done

    echo "=== [4/5] Compiling YAAP 17 ==="
    m yaap
} 2>&1 | tee "${LOG_FILE}"

echo "=== [5/5] Packaging & Dual Cloud Upload (PixelDrain + GoFile) ==="
END_TIME=$(date +%s)
DURATION=$(( (END_TIME - START_TIME) / 60 ))
DURATION_SECS=$(( (END_TIME - START_TIME) % 60 ))

OUT_DIR="out/target/product/${DEVICE}"
ROM_ZIP=$(find "${OUT_DIR}" -maxdepth 1 \( -name "YAAP-*.zip" -o -name "*.zip" \) ! -name "*ota*" | head -n 1)

ZIP_NAME="None"
ZIP_SIZE="0"
ZIP_MD5="None"
PD_ROM_URL=""
GF_ROM_URL=""

if [[ -f "${ROM_ZIP}" ]]; then
    ZIP_NAME=$(basename "${ROM_ZIP}")
    ZIP_SIZE=$(du -h "${ROM_ZIP}" | awk '{print $1}')
    ZIP_MD5=$(md5sum "${ROM_ZIP}" | awk '{print $1}')
    
    # Upload ROM to both providers
    PD_ROM_URL=$(upload_to_pixeldrain "${ROM_ZIP}")
    GF_ROM_URL=$(upload_to_gofile "${ROM_ZIP}")
fi

# Partition Images Upload (Boot, Vendor_boot / Recovery)
BOOT_IMG="${OUT_DIR}/boot.img"
VBOOT_IMG="${OUT_DIR}/vendor_boot.img"

PD_BOOT_URL=""
GF_BOOT_URL=""
PD_VBOOT_URL=""
GF_VBOOT_URL=""

if [[ -f "${BOOT_IMG}" ]]; then
    PD_BOOT_URL=$(upload_to_pixeldrain "${BOOT_IMG}")
    GF_BOOT_URL=$(upload_to_gofile "${BOOT_IMG}")
fi

if [[ -f "${VBOOT_IMG}" ]]; then
    PD_VBOOT_URL=$(upload_to_pixeldrain "${VBOOT_IMG}")
    GF_VBOOT_URL=$(upload_to_gofile "${VBOOT_IMG}")
fi

# Construct Dual Provider Buttons
BUTTON_ROWS=()

# Row 1: Dual ROM Download Mirrors
ROM_ROW=()
[[ -n "${PD_ROM_URL}" ]] && ROM_ROW+=("{\"text\":\"PixelDrain Mirror\",\"url\":\"${PD_ROM_URL}\"}")
[[ -n "${GF_ROM_URL}" ]] && ROM_ROW+=("{\"text\":\"GoFile Mirror\",\"url\":\"${GF_ROM_URL}\"}")

if [[ ${#ROM_ROW[@]} -gt 0 ]]; then
    ROW1=$(IFS=,; echo "${ROM_ROW[*]}")
    BUTTON_ROWS+=("[${ROW1}]")
fi

# Row 2: Boot Image Mirrors
BOOT_ROW=()
[[ -n "${PD_BOOT_URL}" ]] && BOOT_ROW+=("{\"text\":\"Boot (PixelDrain)\",\"url\":\"${PD_BOOT_URL}\"}")
[[ -n "${GF_BOOT_URL}" ]] && BOOT_ROW+=("{\"text\":\"Boot (GoFile)\",\"url\":\"${GF_BOOT_URL}\"}")

if [[ ${#BOOT_ROW[@]} -gt 0 ]]; then
    ROW2=$(IFS=,; echo "${BOOT_ROW[*]}")
    BUTTON_ROWS+=("[${ROW2}]")
fi

# Row 3: Vendor Boot (Recovery) Mirrors
VBOOT_ROW=()
[[ -n "${PD_VBOOT_URL}" ]] && VBOOT_ROW+=("{\"text\":\"Vendor Boot (PixelDrain)\",\"url\":\"${PD_VBOOT_URL}\"}")
[[ -n "${GF_VBOOT_URL}" ]] && VBOOT_ROW+=("{\"text\":\"Vendor Boot (GoFile)\",\"url\":\"${GF_VBOOT_URL}\"}")

if [[ ${#VBOOT_ROW[@]} -gt 0 ]]; then
    ROW3=$(IFS=,; echo "${VBOOT_ROW[*]}")
    BUTTON_ROWS+=("[${ROW3}]")
fi

KEYBOARD_JSON=""
if [[ ${#BUTTON_ROWS[@]} -gt 0 ]]; then
    KEYBOARD_JSON=$(IFS=,; echo "{\"inline_keyboard\":[${BUTTON_ROWS[*]}]}")
fi

success_msg="<pre>
┌──[ BUILD COMPLETE &amp; UPLOADED ]
│
├── TARGET   : Tecno Pova 5 Pro (${DEVICE})
├── ROM      : YAAP 17
├── BRANCH   : ${BRANCH}
├── TYPE     : user
├── FILE     : ${ZIP_NAME}
├── SIZE     : ${ZIP_SIZE}
├── TIME     : ${DURATION}m ${DURATION_SECS}s
├── MD5      : ${ZIP_MD5}
│
└──[ STATUS  : READY TO FLASH ]
</pre>
<b>Built by:</b> @Swaggyxren"

if [[ -n "${KEYBOARD_JSON}" ]]; then
    tg_send_message_with_buttons "${success_msg}" "${KEYBOARD_JSON}"
else
    tg_send_message "${success_msg}"
fi

echo "=== YAAP Build & Upload Workflow Completed in ${DURATION}m ${DURATION_SECS}s ==="
