source "${HOME}/lib/bash/handle_ssh_agent.bash"

unalias r 2> /dev/null
function r {
    if [[ -z ${1} ]]; then
        echo "ERROR: argument required"
        return 1
    fi
    echo
    echo "Press <Enter> to execute or signal interrupt to cancel:"
    fc -ln "${1}" "${1}"
    typeset dummy
    read dummy
    fc -e - "${1}"
}

function lwhich {
  less "$(which ${1})"
}

function pruhf {
    typeset file
    if [[ ${1} == /* ]]; then
        file=${1}
    else
        file=${PWD}/${1}
    fi
    if [[ -d ${file} && ${file} != */ ]]; then
        file=${file}/
    fi
    echo "$(whoami)@$(hostname):${file}"
}

# too bad banner is not available on some platforms, like Linux
type banner > /dev/null 2>&1 || {
    function banner {
        typeset width='                                                         '
        typeset message=$(echo "${*}" | tr "[:lower:]" "[:upper:]")
        echo
        echo " #-------------------------------------------------------------#"
        echo " #                                                             #"
        echo " #  ${message}${width:${#message}}  #"
        echo " #                                                             #"
        echo " #-------------------------------------------------------------#"
        echo " #-------------------------------------------------------------#"
        echo
    }
}
