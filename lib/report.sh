#!/bin/bash
# TXT + JSON + Markdown report generation.
#
# generate_report() gathers every metric once into local variables, then
# hands off to three writer functions. Bash's dynamic scoping means a
# function sees the `local` variables of whatever function is currently
# calling it, so _report_write_txt/_json/_md below can read dd_bytes,
# ds_bytes, etc. without generate_report threading two dozen parameters
# through - the alternative would be gathering everything three times
# (one per format), which is exactly the kind of duplication this project
# avoids elsewhere.

_report_macos_version() {
    sw_vers -productVersion 2>/dev/null || echo "unknown"
}

_report_recommendations() {
    # Prints one recommendation per line for anything worth calling out
    # (threshold: 500 MB).
    local threshold=524288000
    local dd ds ar pub grc pod npmc yarnc bun_c

    dd="$(xcode_derived_data_bytes 2>/dev/null || echo 0)"
    ds="$(xcode_devicesupport_bytes 2>/dev/null || echo 0)"
    ar="$(xcode_archives_bytes 2>/dev/null || echo 0)"
    pub="$(flutter_pub_cache_bytes 2>/dev/null || echo 0)"
    grc="$(gradle_caches_bytes 2>/dev/null || echo 0)"
    pod="$(cocoapods_cache_bytes 2>/dev/null || echo 0)"
    npmc="$(node_npm_cache_bytes 2>/dev/null || echo 0)"
    yarnc="$(node_yarn_cache_bytes 2>/dev/null || echo 0)"
    bun_c="$(bun_cache_bytes 2>/dev/null || echo 0)"

    [ "$dd" -gt "$threshold" ] && echo "Xcode DerivedData is $(human_size "$dd") - safe to clean with 'devclean clean'."
    [ "$ds" -gt "$threshold" ] && echo "iOS DeviceSupport is $(human_size "$ds") - review old versions in the Xcode cleanup menu."
    [ "$ar" -gt "$threshold" ] && echo "Xcode Archives total $(human_size "$ar") - review old archives you no longer need to re-symbolicate."
    [ "$pub" -gt "$threshold" ] && echo "Dart/Flutter pub-cache is $(human_size "$pub") - safe to clean, will be redownloaded."
    [ "$grc" -gt "$threshold" ] && echo "Gradle caches are $(human_size "$grc") - safe to clean, will be redownloaded."
    [ "$pod" -gt "$threshold" ] && echo "CocoaPods cache is $(human_size "$pod") - safe to clean, will be redownloaded."
    [ "$npmc" -gt "$threshold" ] && echo "npm cache is $(human_size "$npmc") - safe to clean with 'npm cache clean --force'."
    [ "$yarnc" -gt "$threshold" ] && echo "yarn cache is $(human_size "$yarnc") - safe to clean with 'yarn cache clean'."
    [ "$bun_c" -gt "$threshold" ] && echo "Bun cache is $(human_size "$bun_c") - safe to clean with 'bun pm cache rm'."

    if command_exists docker && docker_available 2>/dev/null; then
        local dr
        dr="$(docker_reclaimable_bytes 2>/dev/null || echo 0)"
        [ "$dr" -gt "$threshold" ] && echo "Docker reports $(human_size "$dr") reclaimable - review with 'devclean' Docker cleanup."
    fi
}

_report_write_txt() {
    local txt_path="$1"
    {
        echo "devclean report"
        echo "generated_at: $generated_at"
        echo "hostname:     $hostname_v"
        echo "macos:        $macos_v"
        echo
        echo "== Disk =="
        echo "total: $(human_size "$disk_total")"
        echo "used:  $(human_size "$disk_used")"
        echo "free:  $(human_size "$disk_free")"
        echo
        echo "== Xcode =="
        echo "DerivedData:      $(human_size "$dd_bytes")"
        echo "iOS DeviceSupport: $(human_size "$ds_bytes")"
        echo "Archives:         $(human_size "$ar_bytes")"
        echo
        echo "== Simulator =="
        echo "devices:       $sim_count (booted: $sim_booted)"
        echo "devices data:  $(human_size "$sim_devices_bytes")"
        echo "caches:        $(human_size "$sim_caches_bytes")"
        echo
        echo "== Flutter / Dart =="
        echo "pub-cache: $(human_size "$pub_bytes")"
        echo "SDK cache: $(human_size "$sdk_cache_bytes")"
        echo
        echo "== Gradle =="
        echo "caches:  $(human_size "$gradle_c")"
        echo "wrapper: $(human_size "$gradle_w")"
        echo
        echo "== Android =="
        echo "SDK (report only): $(human_size "$android_sdk")"
        echo "AVDs:              $(human_size "$android_avd")"
        echo "~/.android:        $(human_size "$android_dot")"
        echo
        echo "== CocoaPods =="
        echo "cache:      $(human_size "$pod_cache")"
        echo "~/.cocoapods: $(human_size "$pod_dot")"
        echo
        echo "== Node =="
        echo "npm cache:  $(human_size "$npm_c")"
        echo "yarn cache: $(human_size "$yarn_c")"
        echo "pnpm store: $(human_size "$pnpm_c")$([ -n "$pnpm_ver" ] && echo " (v$pnpm_ver)")"
        echo
        echo "== Bun =="
        echo "installed: $bun_installed"
        [ "$bun_installed" = "true" ] && echo "cache:     $(human_size "$bun_c")"
        echo
        echo "== Docker =="
        echo "available:  $docker_is_available"
        [ "$docker_is_available" = "true" ] && echo "reclaimable: $(human_size "$docker_reclaim")"
        echo
        echo "== Homebrew =="
        echo "available: $brew_is_available"
        [ "$brew_is_available" = "true" ] && echo "cache:     $(human_size "$brew_c")"
        echo
        echo "== WhatsApp (audit only) =="
        echo "total: $(human_size "$whatsapp_bytes")"
        echo
        echo "== Summary =="
        echo "estimated reclaimable: $(human_size "$estimated_reclaimable")"
        echo
        echo "== Recommendations =="
        if [ -n "$recommendations" ]; then
            printf '%s\n' "$recommendations"
        else
            echo "No significant cleanup opportunities found."
        fi
    } > "$txt_path"
}

_report_write_json() {
    local json_path="$1"
    {
        printf '{\n'
        printf '  "generated_at": %s,\n' "$(json_str "$generated_at")"
        printf '  "hostname": %s,\n' "$(json_str "$hostname_v")"
        printf '  "macos_version": %s,\n' "$(json_str "$macos_v")"
        printf '  "disk": {"total_bytes": %d, "used_bytes": %d, "free_bytes": %d},\n' "$disk_total" "$disk_used" "$disk_free"
        printf '  "xcode": {"derived_data_bytes": %d, "device_support_bytes": %d, "archives_bytes": %d},\n' "$dd_bytes" "$ds_bytes" "$ar_bytes"
        printf '  "simulator": {"device_count": %d, "booted_count": %d, "devices_bytes": %d, "caches_bytes": %d},\n' "$sim_count" "$sim_booted" "$sim_devices_bytes" "$sim_caches_bytes"
        printf '  "flutter": {"pub_cache_bytes": %d, "sdk_cache_bytes": %d},\n' "$pub_bytes" "$sdk_cache_bytes"
        printf '  "gradle": {"caches_bytes": %d, "wrapper_bytes": %d},\n' "$gradle_c" "$gradle_w"
        printf '  "android": {"sdk_bytes": %d, "avd_bytes": %d, "dot_dir_bytes": %d},\n' "$android_sdk" "$android_avd" "$android_dot"
        printf '  "cocoapods": {"cache_bytes": %d, "dot_dir_bytes": %d},\n' "$pod_cache" "$pod_dot"
        printf '  "node": {"npm_cache_bytes": %d, "yarn_cache_bytes": %d, "pnpm_store_bytes": %d, "pnpm_version": %s},\n' "$npm_c" "$yarn_c" "$pnpm_c" "$(json_str "$pnpm_ver")"
        printf '  "bun": {"installed": %s, "cache_bytes": %d, "version": %s},\n' "$bun_installed" "$bun_c" "$(json_str "$bun_ver")"
        printf '  "docker": {"available": %s, "reclaimable_bytes": %d},\n' "$docker_is_available" "$docker_reclaim"
        printf '  "homebrew": {"available": %s, "cache_bytes": %d},\n' "$brew_is_available" "$brew_c"
        printf '  "whatsapp": {"total_bytes": %d},\n' "$whatsapp_bytes"
        printf '  "estimated_reclaimable_bytes": %d,\n' "$estimated_reclaimable"
        printf '  "recommendations": ['
        if [ -n "$recommendations" ]; then
            local first=1 line
            while IFS= read -r line; do
                [ -z "$line" ] && continue
                if [ "$first" -eq 1 ]; then
                    first=0
                else
                    printf ','
                fi
                printf '\n    %s' "$(json_str "$line")"
            done <<< "$recommendations"
            printf '\n  ]\n'
        else
            printf ']\n'
        fi
        printf '}\n'
    } > "$json_path"
}

_report_write_md() {
    local md_path="$1"
    {
        echo "# System Summary"
        echo
        echo "**Generated:** $generated_at"
        echo
        echo "**Host:** $hostname_v - macOS $macos_v"
        echo
        echo "## Disk"
        echo
        echo "| Metric | Value |"
        echo "|---|---|"
        echo "| Total | $(human_size "$disk_total") |"
        echo "| Used | $(human_size "$disk_used") |"
        echo "| Free | $(human_size "$disk_free") |"
        echo
        echo "## Developer Tools"
        echo
        echo "| Tool | Status |"
        echo "|---|---|"
        echo "| Flutter SDK cache | $(human_size "$sdk_cache_bytes") |"
        echo "| Simulator devices | $sim_count (booted: $sim_booted) |"
        echo "| Android SDK | $([ -d "$ANDROID_HOME_DIR" ] && echo "installed (report only)" || echo "not found") |"
        echo "| Docker | $([ "$docker_is_available" = "true" ] && echo "running" || echo "not available") |"
        echo "| Homebrew | $([ "$brew_is_available" = "true" ] && echo "installed" || echo "not installed") |"
        echo "| pnpm | $([ -n "$pnpm_ver" ] && echo "v$pnpm_ver" || echo "not installed") |"
        echo "| Bun | $([ "$bun_installed" = "true" ] && echo "v$bun_ver" || echo "not installed") |"
        echo
        echo "## Caches"
        echo
        echo "| Cache | Size |"
        echo "|---|---|"
        echo "| Xcode DerivedData | $(human_size "$dd_bytes") |"
        echo "| iOS DeviceSupport | $(human_size "$ds_bytes") |"
        echo "| Xcode Archives | $(human_size "$ar_bytes") |"
        echo "| Simulator device data | $(human_size "$sim_devices_bytes") |"
        echo "| Flutter pub-cache | $(human_size "$pub_bytes") |"
        echo "| Gradle caches | $(human_size "$gradle_c") |"
        echo "| CocoaPods cache | $(human_size "$pod_cache") |"
        echo "| npm cache | $(human_size "$npm_c") |"
        echo "| yarn cache | $(human_size "$yarn_c") |"
        echo "| pnpm store | $(human_size "$pnpm_c") |"
        echo "| Bun cache | $(human_size "$bun_c") |"
        echo "| Homebrew cache | $(human_size "$brew_c") |"
        [ "$docker_is_available" = "true" ] && echo "| Docker reclaimable | $(human_size "$docker_reclaim") |"
        echo
        echo "## Estimated Reclaimable"
        echo
        echo "**$(human_size "$estimated_reclaimable")**"
        echo
        echo "## Recommendations"
        echo
        if [ -n "$recommendations" ]; then
            local line
            while IFS= read -r line; do
                [ -z "$line" ] && continue
                echo "- $line"
            done <<< "$recommendations"
        else
            echo "No significant cleanup opportunities found."
        fi
    } > "$md_path"
}

generate_report() {
    mkdir -p "$REPORTS_DIR" 2>/dev/null
    local ts txt_path json_path md_path
    ts="$(timestamp)"
    txt_path="$REPORTS_DIR/devclean-report-${ts}.txt"
    json_path="$REPORTS_DIR/devclean-report-${ts}.json"
    md_path="$REPORTS_DIR/devclean-report-${ts}.md"

    local generated_at hostname_v macos_v
    generated_at="$(iso_timestamp)"
    hostname_v="$(hostname 2>/dev/null)"
    macos_v="$(_report_macos_version)"

    local disk_total disk_used disk_free
    disk_total="$(disk_total_bytes)"
    disk_used="$(disk_used_bytes)"
    disk_free="$(disk_free_bytes)"

    local dd_bytes ds_bytes ar_bytes
    dd_bytes="$(xcode_derived_data_bytes)"
    ds_bytes="$(xcode_devicesupport_bytes)"
    ar_bytes="$(xcode_archives_bytes)"

    simulator_collect 2>/dev/null || true
    local sim_count="${#_SIM_UUID[@]}"
    local sim_booted=0 _i
    for ((_i = 0; _i < sim_count; _i++)); do
        [ "${_SIM_STATE[$_i]}" = "Booted" ] && sim_booted=$((sim_booted + 1))
    done
    local sim_devices_bytes sim_caches_bytes
    sim_devices_bytes="$(simulator_devices_bytes)"
    sim_caches_bytes="$(simulator_caches_bytes)"

    local pub_bytes sdk_cache_bytes
    pub_bytes="$(flutter_pub_cache_bytes)"
    sdk_cache_bytes="$(flutter_sdk_cache_bytes)"

    local gradle_c gradle_w
    gradle_c="$(gradle_caches_bytes)"
    gradle_w="$(gradle_wrapper_bytes)"

    local android_sdk android_avd android_dot
    android_sdk="$(android_sdk_bytes)"
    android_avd="$(android_avd_bytes)"
    android_dot="$(android_dot_dir_bytes)"

    local pod_cache pod_dot
    pod_cache="$(cocoapods_cache_bytes)"
    pod_dot="$(cocoapods_dot_dir_bytes)"

    local npm_c yarn_c pnpm_c pnpm_ver
    npm_c="$(node_npm_cache_bytes)"
    yarn_c="$(node_yarn_cache_bytes)"
    pnpm_c="$(node_pnpm_store_bytes)"
    pnpm_ver="$(node_pnpm_version)"

    local bun_installed="false" bun_c=0 bun_ver=""
    if bun_available; then
        bun_installed="true"
        bun_c="$(bun_cache_bytes)"
        bun_ver="$(bun_version)"
    fi

    local docker_is_available="false" docker_reclaim=0
    if command_exists docker && docker_available 2>/dev/null; then
        docker_is_available="true"
        docker_reclaim="$(docker_reclaimable_bytes)"
    fi

    local brew_is_available="false" brew_c=0
    if brew_available 2>/dev/null; then
        brew_is_available="true"
        brew_c="$(brew_cache_bytes)"
    fi

    local whatsapp_bytes
    whatsapp_bytes="$(whatsapp_container_bytes)"

    local estimated_reclaimable
    estimated_reclaimable="$(estimate_reclaimable_bytes)"

    local recommendations
    recommendations="$(_report_recommendations)"

    _report_write_txt "$txt_path"
    _report_write_json "$json_path"
    _report_write_md "$md_path"

    log_info "Generated report: $txt_path"
    log_info "Generated report: $json_path"
    log_info "Generated report: $md_path"

    printf '%s\n' "$txt_path"
    printf '%s\n' "$json_path"
    printf '%s\n' "$md_path"
}

report_command() {
    section_header "Generating report"
    local txt_path json_path md_path
    { read -r txt_path; read -r json_path; read -r md_path; } < <(generate_report)
    echo "TXT report:      $txt_path"
    echo "JSON report:     $json_path"
    echo "Markdown report: $md_path"
}
