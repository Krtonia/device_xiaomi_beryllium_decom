#!/bin/bash
#
# Copyright (C) 2016 The CyanogenMod Project
# Copyright (C) 2017-2020 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

set -e

DEVICE=beryllium
VENDOR=xiaomi

# Load extract_utils and do some sanity checks
MY_DIR="${BASH_SOURCE%/*}"
if [[ ! -d "${MY_DIR}" ]]; then MY_DIR="${PWD}"; fi

ANDROID_ROOT="${MY_DIR}/../../../../.."

HELPER="${ANDROID_ROOT}/tools/extract-utils/extract_utils.sh"
if [ ! -f "${HELPER}" ]; then
    echo "Unable to find helper script at ${HELPER}"
    exit 1
fi
source "${HELPER}"

# Default to sanitizing the vendor folder before extraction
CLEAN_VENDOR=true

KANG=
SECTION=

while [ "${#}" -gt 0 ]; do
    case "${1}" in
        -n | --no-cleanup )
                CLEAN_VENDOR=false
                ;;
        -k | --kang )
                KANG="--kang"
                ;;
        -s | --section )
                SECTION="${2}"; shift
                CLEAN_VENDOR=false
                ;;
        * )
                SRC="${1}"
                ;;
    esac
    shift
done

if [ -z "${SRC}" ]; then
    SRC="adb"
fi

function blob_fixup() {
    case "${1}" in
        system_ext/etc/permissions/qcrilhook.xml)
            sed -i "s/\/product\/framework\//\/system_ext\/framework\//g" "${2}"
            ;;
        system_ext/etc/permissions/qti_libpermissions.xml)
            sed -i "s/name=\"android.hidl.manager-V1.0-java/name=\"android.hidl.manager@1.0-java/g" "${2}"
            ;;
        system_ext/lib64/lib-imsvideocodec.so)
            grep -q "libgui_shim.so" "${2}" || ${PATCHELF} --add-needed "libgui_shim.so" "${2}"
            ;;
        vendor/lib/camera/components/com.qti.node.watermark.so)
            grep -q "libpiex_shim.so" "${2}" || ${PATCHELF} --add-needed "libpiex_shim.so" "${2}"
            ;;

        vendor/lib/mediadrm/libwvdrmengine.so | vendor/lib64/mediadrm/libwvdrmengine.so | vendor/lib64/libwvhidl.so)
            ${PATCHELF}  --replace-needed "libprotobuf-cpp-lite-3.9.1.so" "libprotobuf-cpp-full-3.9.1.so" "${2}"
            ;;

        vendor/lib/egl/eglSubDriverAndroid.so | vendor/lib/libCB.so | vendor/lib/hw/vulkan.adreno.so | vendor/lib64/egl/eglSubDriverAndroid.so | vendor/lib64/libCB.so | vendor/lib64/hw/vulkan.adreno.so)
            ${PATCHELF}  --replace-needed "vendor.qti.hardware.display.mapper@3.0.so" "vendor.qti.hardware.display.mappershim.so" "${2}" && ${PATCHELF}  --replace-needed "vendor.qti.hardware.display.mapper@4.0.so" "vendor.qti.hardware.display.mappershim.so" "${2}" && ${PATCHELF}  --replace-needed "android.hardware.graphics.mapper@3.0.so" "android.hardware.graphics.mappershim.so" "${2}" && ${PATCHELF}  --replace-needed "android.hardware.graphics.mapper@4.0.so" "android.hardware.graphics.mappershim.so" "${2}"
            ;;

    esac
}

# Initialize the helper
setup_vendor "${DEVICE}" "${VENDOR}" "${ANDROID_ROOT}" false "${CLEAN_VENDOR}"

extract "${MY_DIR}/../../proprietary-files.txt" "${SRC}" "${KANG}" --section "${SECTION}"

"${MY_DIR}/setup-makefiles.sh"
