#!/usr/bin/env bash

export PYTHONPATH="${HOME}/opt/python"
SENSOR="Kai's house"
THRESHOLD=12
function args() {
    OPTS=$(getopt --long sensor:,threshold: -n $(basename "${0}") -- "${@}")
    if [[ ${?} != 0 ]] ; then echo "Failed parsing options." >&2 ; exit 1 ; fi
    eval set -- "${OPTS}"

    RSYNC_DELETE_OPT='--delete --delete-excluded'

    while true; do
        case "${1}" in
            --threshold ) THRESHOLD="${2}"  ;   shift 2 ;;
            --sensor    ) SENSOR="${2}"     ;   shift 2 ;;
            --          ) shift             ;   break   ;;
            *           ) break             ;;
        esac
    done
}

args ${0} "${@}"

HUSH=true
source "${HOME}/etc/handle_ssh-agent.source.sh"
source "${HOME}/opt/pyvenv/bin/activate"
"${HOME}/opt/pyvenv/bin/python" "${HOME}/opt/python/aqi.py" --sensor="${SENSOR}" --threshold="${THRESHOLD}"
