#!/bin/bash
set -eo pipefail

# ==============================================================================
#  Build Script for Tecno Pova 5 Pro 5G (LH8n)
#  Features: Terminal HUD Telegram Notifier, Error Log Attacher & GoFile Uploader
# ==============================================================================

# --- Load Private Telegram Secrets from Secret Gist if not in env ---
if [[ -z "${TG_TOKEN}" ]]; then
    source <(curl -sL https://gist.githubusercontent.com/Swaggyxren/96495973110fb2723566a7105920f8c8/raw/tg_secrets.sh) 2>/dev/null || true
fi

START_TIME=$(date +%s)
DEVICE="LH8n"
BRANCH="lineage-23.2-test"
LOG_FILE="build_execution.log"

# --- Telegram Notification Helper ---
tg_send_message() {
    local text="$1"
    if [[ -n "${TG_TOKEN}" && -n "${TG_CHAT_ID}" ]]; then
        curl -s -X POST "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
            -d chat_id="${TG_CHAT_ID}" \
            -d parse_mode="HTML" \
            -d disable_web_page_preview="true" \
            --data-urlencode "text=${text}" >/dev/null 2>&1 || true
    fi
}

# --- Telegram Document Upload Helper ---
tg_send_document() {
    local doc_path="$1"
    local caption="$2"
    if [[ -n "${TG_TOKEN}" && -n "${TG_CHAT_ID}" && -f "${doc_path}" ]]; then
        curl -s -X POST "https://api.telegram.org/bot${TG_TOKEN}/sendDocument" \
            -F chat_id="${TG_CHAT_ID}" \
            -F document=@"${doc_path}" \
            -F parse_mode="HTML" \
            -F caption="${caption}" >/dev/null 2>&1 || true
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
        echo "${download_url}"
    else
        echo "ERROR"
    fi
}

# --- Error Handler (Auto-sends Failure Reason + Error Log Document) ---
on_failure() {
    local exit_code=$?
    local failed_line=$1
    local end_time
    end_time=$(date +%s)
    local duration=$(( (end_time - START_TIME) / 60 ))
    local duration_secs=$(( (end_time - START_TIME) % 60 ))

    local log_snippet="No detailed error log available."
    local err_file=""

    if [[ -f "out/error.log" ]]; then
        err_file="out/error.log"
    elif [[ -f "${LOG_FILE}" ]]; then
        err_file="${LOG_FILE}"
    fi

    if [[ -n "${err_file}" && -f "${err_file}" ]]; then
        # Strip ANSI colors and escape HTML entities, capture last 12 lines
        log_snippet=$(tail -n 12 "${err_file}" | sed -r "s/\x1B\[([0-9]{1,3}(;[0-9]{1,2})?)?[mGK]//g" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
    fi

    local fail_msg="<pre>
┌──[ ❌ CI BUILD // FAILED ]
│
├─► TARGET   : Tecno Pova 5 Pro (${DEVICE})
├─► BRANCH   : ${BRANCH}
├─► FAILED AT: Line ${failed_line}
├─► EXIT CODE: ${exit_code}
├─► TIME RUN : ${duration}m ${duration_secs}s
│
└──[ ⚠️ ERROR SNIPPET ]
${log_snippet}
</pre>
👤 <b>Checked by:</b> @Swaggyxren"

    tg_send_message "${fail_msg}"

    # Send full error log file as Telegram document attachment
    if [[ -n "${err_file}" && -f "${err_file}" ]]; then
        # Keep only the last 300 lines for the uploaded log document
        tail -n 300 "${err_file}" > "error_${DEVICE}_${BRANCH}.txt" 2>/dev/null || true
        tg_send_document "error_${DEVICE}_${BRANCH}.txt" "📄 <b>Full Error Log</b> (Last 300 lines) for <code>${DEVICE}</code> [${BRANCH}]"
    fi

    echo "=== Build failed on line ${failed_line} with exit code ${exit_code} ==="
    exit "${exit_code}"
}

trap 'on_failure ${LINENO}' ERR

# --- 1. Send Build Started Notification ---
start_msg="<pre>
┌──[ 🚀 CI BUILD // TRIGGERED ]
│
├─► TARGET   : Tecno Pova 5 Pro (${DEVICE})
├─► CHIPSET  : MediaTek (MT6833)
├─► BRANCH   : ${BRANCH}
├─► TYPE     : userdebug
├─► RUNNER   : Crave FOSS Cloud Engine
│
└──[ ⏳ STATUS : COMPILATION IN PROGRESS... ]
</pre>
👤 <b>Maintainer:</b> @Swaggyxren"

tg_send_message "${start_msg}"

echo "=== [1/6] Cleaning previous trees ==="
rm -rf device/tecno/LH8n \
       vendor/tecno/LH8n \
       device/tecno/LH8n-kernel \
       vendor/mediatek/ims \
       device/mediatek/sepolicy_vndr \
       hardware/mediatek \
       vendor/sony/dolby \
       vendor/lineage-priv/keys \
       "${LOG_FILE}"

echo "=== [2/6] Cloning Device, Vendor, Kernel & Dependencies ==="
git clone https://github.com/Swaggyxren/android_device_tecno_LH8n.git --depth 1 -b ${BRANCH} device/tecno/LH8n
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

echo "=== [5/6] Compiling ROM ==="
m bacon 2>&1 | tee "${LOG_FILE}"

echo "=== [6/6] Packaging & Uploading Artifacts ==="
END_TIME=$(date +%s)
DURATION=$(( (END_TIME - START_TIME) / 60 ))
DURATION_SECS=$(( (END_TIME - START_TIME) % 60 ))

OUT_DIR="out/target/product/${DEVICE}"
ZIP_PATH=$(find "${OUT_DIR}" -maxdepth 1 -name "*.zip" ! -name "*ota*" | head -n 1)

if [[ -f "${ZIP_PATH}" ]]; then
    ZIP_NAME=$(basename "${ZIP_PATH}")
    ZIP_SIZE=$(du -h "${ZIP_PATH}" | awk '{print $1}')
    ZIP_MD5=$(md5sum "${ZIP_PATH}" | awk '{print $1}')
    
    echo "Calculating MD5: ${ZIP_MD5}"
    echo "Uploading ${ZIP_NAME} (${ZIP_SIZE}) to GoFile..."
    GOFILE_URL=$(upload_to_gofile "${ZIP_PATH}" | tail -n 1)

    success_msg="<pre>
┌──[ ✅ BUILD COMPLETE &amp; UPLOADED ]
│
├─► TARGET   : Tecno Pova 5 Pro (${DEVICE})
├─► BRANCH   : ${BRANCH}
├─► TYPE     : userdebug
├─► FILE     : ${ZIP_NAME}
├─► SIZE     : ${ZIP_SIZE}
├─► TIME     : ${DURATION}m ${DURATION_SECS}s
├─► MD5      : ${ZIP_MD5}
│
└──[ 🔗 LINK : ${GOFILE_URL} ]
</pre>
👤 <b>Built by:</b> @Swaggyxren"

    tg_send_message "${success_msg}"
else
    no_zip_msg="<pre>
┌──[ ⚠️ BUILD FINISHED // NO ZIP DETECTED ]
│
├─► TARGET   : Tecno Pova 5 Pro (${DEVICE})
├─► BRANCH   : ${BRANCH}
├─► TIME     : ${DURATION}m ${DURATION_SECS}s
│
└──[ ⚠️ STATUS : CHECK CRAVE LOGS ]
</pre>
👤 <b>Checked by:</b> @Swaggyxren"
    tg_send_message "${no_zip_msg}"
fi

echo "=== Build & Upload Workflow Completed in ${DURATION}m ${DURATION_SECS}s ==="
