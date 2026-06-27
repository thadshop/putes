#!/usr/bin/env bash
set -euo pipefail

# ws500-vm-usb-sync.sh
# Detect WS500 connected to host and ensure a given libvirt VM has the matching
# USB hostdev attached (normal mode <-> product 0x5740, DFU mode <-> product 0xdf11).

PROGNAME=$(basename "$0")
VM_NAME=""
DRY_RUN=0
VERBOSE=0
ENSURE_DETACHED=0
WS500_VENDOR_ID="0483"

usage() {
    cat <<EOF
Usage: ${PROGNAME} -n|--name VM_NAME [--dry-run] [--ensure-detached] [-v|--verbose]

Options:
  -n, --name VM_NAME        Name of the libvirt VM to inspect/update
      --dry-run             Print the actions that would be taken,
                            but don't run them
      --ensure-detached     Even if no WS500 is attached, detach any existing
                            WS500 hostdev configuration from the VM.
  -v, --verbose             Increase verbosity.
  -h, --help                Show this help.
EOF
}

info() { printf '%b\n' "[INFO] ${*}"; }
log() {
    if [[ "${VERBOSE}" -eq 1 ]]; then
        printf '%b\n' "[INFO-verbose] ${*}" >&2
    fi
}
err() { printf '%b\n' "[ERROR] ${*}" >&2; }
die() { err "${*}"; exit 1; }

require_cmds() {
    local cmds=(lsusb virsh xmllint grep cut sed tr)
    for c in "${cmds[@]}"; do
        if ! command -v "${c}" >/dev/null 2>&1; then
            die "Required command '${c}' not found in PATH"
        fi
    done
}

parse_args() {
    if [[ "${#}" -eq 0 ]]; then usage; exit 1; fi
    while [[ "${#}" -gt 0 ]]; do
        case "${1}" in
            -n|--name)          VM_NAME="$2"; shift 2           ;;
            --dry-run)          DRY_RUN=1; shift                ;;
            --ensure-detached)  ENSURE_DETACHED=1; shift        ;;
            -v|--verbose)       VERBOSE=1; shift                ;;
            -h|--help)          usage; exit 0                   ;;
            *)                  die "Unknown argument: ${1}"    ;;
        esac
    done
    [[ -n "${VM_NAME}" ]] || die "VM name is required (-n VM_NAME)"
}

wrap_cmd() {
    # runs an arbitrary command and sets variable names it has been passed with
    # the stdout, stderr, and return code of the command:
    #   >   the variable names must be passed as the first three arguments,
    #       in that order
    #   >   the command to run must be passed as the remaining arguments
    local -r _stdout_varname=${1} _stderr_varname=${2} _rc_varname=${3}
    shift 3
    local -ra cmd=("${@}")
    local  cmd_out='' cmd_err='' cmd_rc=''
    printf -v "${_stdout_varname}" ''
    printf -v "${_stderr_varname}" ''
    printf -v "${_rc_varname}"  ''

    trap 'rm -f "${cmd_out-}" "${cmd_err-}"' RETURN
    cmd_out=$(mktemp)
    cmd_err=$(mktemp)

    "${cmd[@]}" >"${cmd_out}" 2>"${cmd_err}" && cmd_rc=0 || cmd_rc=${?}

    printf -v "${_stdout_varname}" '%s' "$( <"${cmd_out}" )"
    printf -v "${_stderr_varname}" '%s' "$( <"${cmd_err}" )"
    printf -v "${_rc_varname}"  '%d' "${cmd_rc}"
}

map_ws500_mode_to_product_id() {
    case "${1}" in
        normal) printf '%s\n' "5740"                ;;
        dfu)    printf '%s\n' "df11"                ;;
        *)      die "Invalid mode '${1}' for WS500" ;;
    esac
}

map_ws500_product_id_to_mode() {
    case "${1}" in
        5740)   printf '%s\n' "normal"                    ;;
        df11)   printf '%s\n' "dfu"                       ;;
        *)      die "Invalid product ID '${1}' for WS500" ;;
    esac
}

get_ws500_host_dev() {
    # List devices for the vendor using lsusb -d to avoid brittle greps. If none are
    # present this returns an empty string.
    local stdout stderr rc
    wrap_cmd stdout stderr rc lsusb -d "${WS500_VENDOR_ID}:"
    if [[ "${rc}" -eq 0 || ( "${rc}" -eq 1 && -z "${stderr}" ) ]]; then
        if [[ $(printf '%s\n' "${stdout}" | wc -l) -gt 1 ]]; then
            die "Multiple WS500 devices detected on host:\n${stdout}\nUnable to process."
        else
            printf '%s\n' "${stdout}"
        fi
    else
        die "Error running lsusb to detect WS500 device: return code=${rc}: \"${stderr}\""
    fi
}

get_ws500_host_dev_mode() {
    # The input should match the output of get_ws500_host_dev().
    # grep no-match exit code 1 is OK.
    local ids_vendor_product=''
    ids_vendor_product=$( printf '%s\n' "${*}" | grep -Eo ": ID ${WS500_VENDOR_ID}:[0-9a-fA-F]+" || (( ${?} == 1 )) )
    map_ws500_product_id_to_mode "$(printf '%s\n' "${ids_vendor_product}" | cut -d: -f3 | tr '[:upper:]' '[:lower:]')"
}

get_ws500_vm_dev_xml() {
    local stdout stderr rc
    wrap_cmd stdout stderr rc xmllint --xpath "//domain/devices/hostdev[@mode='subsystem' and @type='usb' and @managed='yes' and source/vendor[@id='0x${WS500_VENDOR_ID}']]" <(virsh dumpxml "${VM_NAME}")
    if [[ "${rc}" -eq 0 || ( "${rc}" -eq 10 && "${stderr}" == 'XPath set is empty' ) ]]; then
        printf '%s\n' "${stdout}"
    else
        die "Error getting WS500 device configuration on VM ${VM_NAME}: return code=${rc}: \"${stderr}\""
    fi
}

get_ws500_vm_dev_mode() {
    # The input should match the output of get_ws500_vm_dev_xml().
    local dev_xml stdout stderr rc
    dev_xml="${*}"
    wrap_cmd stdout stderr rc xmllint --xpath 'string(//hostdev/source/product/@id)' <(printf '%s\n' "${dev_xml}")
    if [[ "${rc}" -ne 0 ]]; then
        die "Error extracting product ID from WS500 VM hostdev XML: return code=${rc}: \"${stderr}\""
    fi
    #printf '%s\n' "DEBUG gw5vdm product id: \"${stdout}\""
    map_ws500_product_id_to_mode "$(printf '%s\n' "${stdout}" | sed 's/^0x//' | tr '[:upper:]' '[:lower:]')"
}

# Construct VM's hostdev XML for WS500 of given product ID.
# WS500 mode expected as argument 1.
make_ws500_vm_dev_xml() {
    cat <<EOF
<hostdev mode="subsystem" type="usb" managed="yes">
    <source>
        <vendor id="0x${WS500_VENDOR_ID}"/>
        <product id="0x$(map_ws500_mode_to_product_id "${1}")"/>
    </source>
</hostdev>
EOF
}

attach_ws500_vm_hostdev() {
    local mode hostdev_xml stdout stderr rc
    mode="${1}"
    hostdev_xml=$(make_ws500_vm_dev_xml "${mode}")
    log "Attaching hostdev for WS500 in ${mode} mode to VM ${VM_NAME} with XML:\n${hostdev_xml}"

    if [[ "${DRY_RUN}" -eq 1 ]]; then
        info "DRY-RUN: hostdev XML to attach to ${VM_NAME}:\n${hostdev_xml}"
    else
        wrap_cmd stdout stderr rc virsh attach-device "${VM_NAME}" --live --file <(printf '%s\n' "${hostdev_xml}")
        [[ -z "${stdout}" ]] || log "virsh attach-device: ${stdout}"
        [[ -z "${stderr}" ]] || log "virsh attach-device: ${stderr}"
        if [[ "${rc}" -eq 0 ]]; then
            log "Attached hostdev for WS500 in ${mode} mode to VM ${VM_NAME}"
        else
            err "Failed to attach hostdev for WS500 in ${mode} mode to VM ${VM_NAME}"
            return 1
        fi
    fi
}

detach_ws500_vm_hostdev() {
    local hostdev_xml stdout stderr rc
    hostdev_xml=$(get_ws500_vm_dev_xml)
    if [[ -z "${hostdev_xml}" ]]; then
        log "No WS500 vm hostdev found to detach from VM ${VM_NAME}."
        return 0
    fi
    log "Found WS500 hostdev attached to VM ${VM_NAME}:\n${hostdev_xml}"

    if [[ "${DRY_RUN}" -eq 1 ]]; then
        info "DRY-RUN: Will not detach hostdev."
    else
        wrap_cmd stdout stderr rc virsh detach-device "${VM_NAME}" --live --file <(printf '%s\n' "${hostdev_xml}")
        [[ -z "${stdout}" ]] || log "virsh detach-device: ${stdout}"
        [[ -z "${stderr}" ]] || log "virsh detach-device: ${stderr}"
        if [[ "${rc}" -eq 0 ]]; then
            log "Detached hostdev."
        else
            err "Failed to detach hostdev."
            return 1
        fi
    fi
}

main() {
    parse_args "${@}"
    require_cmds

    local ws500_host_dev vm_ws500_dev_xml host_mode vm_mode

    ws500_host_dev=$(get_ws500_host_dev)
    vm_ws500_dev_xml=$(get_ws500_vm_dev_xml)

    if [[ -z "${ws500_host_dev}" ]]; then
        info "No WS500 detected on host."
        if [[ "${ENSURE_DETACHED}" -eq 1 ]]; then
            info "Ensuring no WS500 hostdev is attached to VM ${VM_NAME}..."
            if [[ -z "${vm_ws500_dev_xml}" ]]; then
                info "No WS500 hostdev is attached."
            else
                info "Found WS500 hostdev attached:\n${vm_ws500_dev_xml}"
                if detach_ws500_vm_hostdev ; then
                    info "Successfully detached it."
                else
                    die "Failed to detach it."
                fi
            fi
        fi
    else
        info "WS500 detected on host."
        log "WS500 host device info: ${ws500_host_dev}"
        host_mode=$(get_ws500_host_dev_mode "${ws500_host_dev}")
        info "WS500 mode on host: ${host_mode}"
        if [[ -z "${vm_ws500_dev_xml}" ]]; then
            info "VM ${VM_NAME} has no WS500 hostdev attached..."
            if attach_ws500_vm_hostdev "${host_mode}"; then
                info "Successfully attached WS500 hostdev for mode ${host_mode} to VM ${VM_NAME}."
            else
                die "Failed to attach WS500 hostdev for mode ${host_mode} to VM ${VM_NAME}."
            fi
        else
            log "VM ${VM_NAME} WS500 hostdev XML:\n${vm_ws500_dev_xml}"
            vm_mode=$(get_ws500_vm_dev_mode "${vm_ws500_dev_xml}")
            info "VM ${VM_NAME} WS500 has hostdev attached for mode ${vm_mode}."
            if [[ "${vm_mode}" != "${host_mode}" ]]; then
                log "VM ${VM_NAME} has WS500 hostdev for incorrect mode ${vm_mode}, will detach it..."
                if detach_ws500_vm_hostdev ; then
                    log "Detached incorrect hostdev."
                else
                    die "Exiting due to failure to detach incorrect hostdev."
                fi
                if attach_ws500_vm_hostdev "${host_mode}"; then
                    log "Successfully attached WS500 hostdev for mode ${host_mode} to VM ${VM_NAME}."
                else
                    die "Exiting due to failure to attach WS500 hostdev for mode ${host_mode} to VM ${VM_NAME}."
                fi
                info "Corrected VM ${VM_NAME} WS500 hostdev from ${vm_mode} to ${host_mode}."
            fi
            info "WS500 in mode ${host_mode} is in sync on host and VM ${VM_NAME}."
        fi
    fi
}

main "${@}"
