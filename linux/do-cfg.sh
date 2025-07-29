#!/usr/bin/env bash

case "${1}" in
    base | server | workstation )
        srcdir="$(dirname "${0}")/${1}"
        ;;
    * )
        echo "ERROR: invalid argument \"${1}\"; expected 'base', 'server', or 'workstation'"
        exit 1
        ;;
esac

srcdir="$(dirname "${0}")/${1}"
tgtdir="${HOME}"

if [[ -d "${srcdir}" && -d "${tgtdir}" ]]; then
    echo "INFO: source \"${srcdir}\"; target \"${tgtdir}\""
else
    echo "ERROR: invalid directories: source \"${srcdir}\"; target \"${tgtdir}\""
    exit 1
fi

# make directories
cfgfile="${srcdir}/mkdirs.cfg"
if [[ -r "${cfgfile}" ]]; then
    echo "INFO: making directories"
    while read d; do
        echo "mkdir -p; chmod 775: \"${tgtdir}/${d}\""
        mkdir -p "${tgtdir}/${d}"
        chmod 775 "${tgtdir}/${d}"
    done < "${cfgfile}"
else
    echo "INFO: no directories to make"
fi

# copy executable files
cfgfile="${srcdir}/copies-exe.cfg"
if [[ -r "${cfgfile}" ]]; then
    echo "INFO: copying executable files"
    while read f; do
        echo "cp; chmod 775: \"${srcdir}/home/${f}\" \"${tgtdir}/${f}\""
        cp "${srcdir}/home/${f}" "${tgtdir}/${f}"
        chmod 775 "${tgtdir}/${f}"
    done < "${cfgfile}"
else
    echo "INFO: no executable files to copy"
fi

# copy regular files
cfgfile="${srcdir}/copies-reg.cfg"
if [[ -r "${cfgfile}" ]]; then
    echo "INFO: copying regular files"
    while read f; do
        echo "cp; chmod 664: \"${srcdir}/home/${f}\" \"${tgtdir}/${f}\""
        cp "${srcdir}/home/${f}" "${tgtdir}/${f}"
        chmod 664 "${tgtdir}/${f}"
    done < "${cfgfile}"
else
    echo "INFO: no regular files to copy"
fi

# do inserts
cfgfile="${srcdir}/inserts.cfg"
if [[ -r "${cfgfile}" ]]; then
    echo "INFO: doing file inserts"
    while read lf; do
        l=$(echo ${lf} | cut -d' ' -f1)
        f=$(echo ${lf} | cut -d' ' -f2)
        #echo "line = ${l}"
        #echo "file = ${f}"
        src="${srcdir}/home/${f}"
        tgt="${tgtdir}/${f}"
        #echo "tgt = ${src}"
        #echo "tgt = ${tgt}"
        if [[ -n $(echo "${l}" | egrep '^[+-][0-9]+') && -f "${src}" && -f "${tgt}" ]]; then
            if [[ "$(grep -Ff "${src}" "${tgt}")" = "$(cat "${src}")" ]]; then
                echo "matching ${f}"
            else
                tgt_lines=$(wc -l < ${tgt})
                #echo "tgt_lines = ${tgt_lines}"
                sedop=''
                if [[ $(echo ${l} | cut -c1) = '+' ]]; then
                    sedop="$(echo ${l} | cut -c2-)a"
                elif [[ $(echo ${l} | cut -c1) = '-' ]]; then
                    sedop="$(( ${tgt_lines} - $(echo ${l} | cut -c2-) ))r"
                fi
                if [[ -n ${sedop} ]]; then
                    #echo "sedop = ${sedop}"
                    sed -i "${sedop} "${src}"" "${tgt}"
                    echo "inserted ${lf}"
                else
                    echo "ERROR: failed to derive sed operand from \"${lf}\""
                fi
            fi
        else
            echo "ERROR: invalid specification \"${lf}\""
        fi
    done < "${cfgfile}"
else
    echo "INFO: no file inserts to do"
fi

# make symlinks
cfgfile="${srcdir}/links-sh.cfg"
if [[ -r "${cfgfile}" ]]; then
    echo "INFO: making symbolic links"
    cat "${cfgfile}"
    source "${cfgfile}"
else
    echo "INFO: no symbolic links to make"
fi
