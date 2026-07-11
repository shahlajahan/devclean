#!/bin/bash
# devclean configuration - default thresholds and well-known paths.
# DEVCLEAN_HOME must already be exported by the caller before this is sourced.

DEVCLEAN_VERSION="1.0.0"

# Directories devclean writes to (created on demand, never assumed to exist).
LOGS_DIR="${DEVCLEAN_HOME}/logs"
REPORTS_DIR="${DEVCLEAN_HOME}/reports"

# devclean's own session logs older than this many days are eligible for
# removal as part of "Quick clean". This never touches system or app logs.
LOG_RETENTION_DAYS="${DEVCLEAN_LOG_RETENTION_DAYS:-30}"

# --- General locations (report only, never bulk-deleted) -------------------
GENERAL_SCAN_PATHS=(
    "/"
    "$HOME/Library"
    "$HOME/Downloads"
    "$HOME/Documents"
    "$HOME/Desktop"
    "$HOME/Pictures"
)

# --- Xcode -------------------------------------------------------------
XCODE_DERIVED_DATA_DIR="$HOME/Library/Developer/Xcode/DerivedData"
XCODE_DEVICE_SUPPORT_DIR="$HOME/Library/Developer/Xcode/iOS DeviceSupport"
XCODE_ARCHIVES_DIR="$HOME/Library/Developer/Xcode/Archives"
CORESIMULATOR_DEVICES_DIR="$HOME/Library/Developer/CoreSimulator/Devices"
CORESIMULATOR_CACHES_DIR="$HOME/Library/Developer/CoreSimulator/Caches"

# --- Flutter / Dart ------------------------------------------------------
PUB_CACHE_DIR="${PUB_CACHE:-$HOME/.pub-cache}"

# --- Android / Gradle ----------------------------------------------------
GRADLE_CACHES_DIR="$HOME/.gradle/caches"
GRADLE_WRAPPER_DIR="$HOME/.gradle/wrapper"
ANDROID_HOME_DIR="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}"
ANDROID_DOT_DIR="$HOME/.android"
ANDROID_AVD_DIR="$HOME/.android/avd"

# --- CocoaPods -------------------------------------------------------------
COCOAPODS_CACHE_DIR="$HOME/Library/Caches/CocoaPods"
COCOAPODS_DOT_DIR="$HOME/.cocoapods"

# --- WhatsApp --------------------------------------------------------------
WHATSAPP_CONTAINER_DIR="$HOME/Library/Group Containers/group.net.whatsapp.WhatsApp.shared"

# --- Quick clean behaviour ---------------------------------------------
# Quick clean only ever touches low-risk, recreatable caches. It must never
# include simulators, DeviceSupport, Archives, Docker, WhatsApp, project
# source, credentials, databases, SSH files, signing material, or .env files.
QUICK_CLEAN_LABEL="Quick clean (safe caches only)"
