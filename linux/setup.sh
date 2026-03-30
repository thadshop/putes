#!/usr/bin/env bash
# Deploy putes home files: always applies linux/base/home, then linux/<workstation|server>/home.
# Not on PATH; run from your clone, e.g. ./linux/setup.sh workstation
# Requires: bash, cp, mkdir, chmod, cat, mv; optional: git for tracked-file listing.

case "${1:-}" in
    workstation | server )
        profile="${1}"
        ;;
    * )
        echo "ERROR: usage: ${0##*/} workstation|server" >&2
        exit 1
        ;;
esac

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tgtdir="${HOME}"
base_home="${script_dir}/base/home"
prof_home="${script_dir}/${profile}/home"
reporoot="$(git -C "${script_dir}" rev-parse --show-toplevel 2>/dev/null)" || reporoot=''

HOME_LAYOUT_DIR_MODE='775'
DOT_BEFORE="${script_dir}/base/bashrc.dotfile.before-skel.bash"
DOT_AFTER="${script_dir}/base/bashrc.dotfile.after-skel.bash"

# Paths under home/ that are assembled by assemble_etc_bash_rc — not copied verbatim.
skip_home_deploy_rel() {
    local rel="${1}"
    [[ "${rel}" == etc/bash/rc/* ]]
}

ensure_home_rel_dir() {
    local rel="${1}"
    [[ -z "${rel}" || "${rel}" == '.' ]] && return 0
    rel="${rel#/}"
    rel="${rel%/}"
    [[ -z "${rel}" ]] && return 0
    mkdir -p "${tgtdir}/${rel}"
    local cur="${tgtdir}"
    local rest="${rel}"
    local part
    while [[ -n "${rest}" ]]; do
        part="${rest%%/*}"
        rest="${rest#"${part}"}"
        rest="${rest#/}"
        cur="${cur}/${part}"
        chmod "${HOME_LAYOUT_DIR_MODE}" "${cur}"
    done
}

copy_one_home_file() {
    local rel="${1}"
    local local_src="${2}"
    local local_tgt="${tgtdir}/${rel}"
    [[ -z "${rel}" ]] && return 0
    if skip_home_deploy_rel "${rel}"; then
        echo "INFO: skip (assembled later): ${rel}"
        return 0
    fi
    if [[ ! -e "${local_src}" ]]; then
        echo "WARN: skip missing source \"${local_src}\""
        return 0
    fi
    ensure_home_rel_dir "$(dirname "${rel}")"
    if [[ -x "${local_src}" ]]; then
        echo "cp; chmod 775: \"${local_src}\" \"${local_tgt}\""
        cp "${local_src}" "${local_tgt}"
        chmod 775 "${local_tgt}"
    else
        echo "cp; chmod 664: \"${local_src}\" \"${local_tgt}\""
        cp "${local_src}" "${local_tgt}"
        chmod 664 "${local_tgt}"
    fi
}

# Copy one tree: git ls-files for prefix, else find on home_root.
deploy_home_tree() {
    local label="${1}"
    local home_root="${2}"
    local git_prefix="${3}"

    if [[ ! -d "${home_root}" ]]; then
        echo "WARN: ${label}: missing directory \"${home_root}\" (skipping)"
        return 0
    fi

    echo "INFO: copying ${label} from \"${home_root}\""
    local copy_n='0'

    if [[ -n "${reporoot}" ]] && git -C "${reporoot}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        while IFS= read -r -d '' path; do
            local rel="${path#"${git_prefix}/"}"
            if [[ "${rel}" == "${path}" ]]; then
                echo "WARN: skip git path not under ${git_prefix}/: ${path}"
                continue
            fi
            copy_one_home_file "${rel}" "${reporoot}/${path}"
            copy_n=$((copy_n + 1))
        done < <(git -C "${reporoot}" ls-files -z "${git_prefix}" 2>/dev/null || true)
    fi

    if [[ "${copy_n}" -eq 0 ]]; then
        echo "WARN: ${label}: no files from git; falling back to find \"${home_root}\""
        local home_slash="${home_root}/"
        while IFS= read -r -d '' local_src; do
            local rel="${local_src#"${home_slash}"}"
            copy_one_home_file "${rel}" "${local_src}"
        done < <(find "${home_root}" -type f -print0 2>/dev/null || true)
    fi
}

# cat base fragment > ~/etc/bash/rc/<name>.bash; cat profile fragment >> same (if present).
assemble_etc_bash_rc() {
    local names=(variables aliases functions)
    local n base_f prof_f out

    mkdir -p "${tgtdir}/etc/bash/rc"
    for n in "${names[@]}"; do
        base_f="${base_home}/etc/bash/rc/${n}.bash"
        prof_f="${prof_home}/etc/bash/rc/${n}.bash"
        out="${tgtdir}/etc/bash/rc/${n}.bash"
        if [[ ! -f "${base_f}" ]]; then
            echo "ERROR: missing base fragment \"${base_f}\"" >&2
            exit 1
        fi
        cat "${base_f}" > "${out}"
        if [[ -f "${prof_f}" ]]; then
            cat "${prof_f}" >> "${out}"
        fi
        chmod 644 "${out}"
        echo "INFO: assembled \"${out}\""
    done
}

if [[ ! -d "${tgtdir}" ]]; then
    echo "ERROR: HOME not a directory: ${tgtdir}" >&2
    exit 1
fi

echo "INFO: putes setup profile=\"${profile}\"; target \"${tgtdir}\""

deploy_home_tree "base" "${base_home}" "linux/base/home"
deploy_home_tree "${profile}" "${prof_home}" "linux/${profile}/home"

assemble_etc_bash_rc

# ~/.bashrc: optional comment snippets (repo) + /etc/skel + optional + source ~/etc/bash/rc/*.bash
if [[ -r /etc/skel/.bashrc ]]; then
    echo "INFO: writing \"${tgtdir}/.bashrc\" from /etc/skel/.bashrc + ~/etc/bash/rc/{variables,aliases,functions}.bash"
    {
        [[ -r "${DOT_BEFORE}" ]] && cat "${DOT_BEFORE}"
        cat /etc/skel/.bashrc
        [[ -r "${DOT_AFTER}" ]] && cat "${DOT_AFTER}"
        cat <<'PUTES_BASHRC_TAIL'

if [[ "${-}" == *i* ]]; then
    echo -e "$(date)\t####-->> Starting  Thad's additions to .bashrc <<--####" | tee -a "${HOME}/log/tevent.log" | cut -f2-
    [[ -r "${HOME}/etc/bash/rc/variables.bash"  ]] && source "${HOME}/etc/bash/rc/variables.bash"
    [[ -r "${HOME}/etc/bash/rc/aliases.bash"    ]] && source "${HOME}/etc/bash/rc/aliases.bash"
    [[ -r "${HOME}/etc/bash/rc/functions.bash"  ]] && source "${HOME}/etc/bash/rc/functions.bash"
    echo -e "$(date)\t####-->> Done with Thad's additions to .bashrc <<--####" | tee -a "${HOME}/log/tevent.log" | cut -f2-
fi
PUTES_BASHRC_TAIL
    } > "${tgtdir}/.bashrc.tmp"
    chmod 644 "${tgtdir}/.bashrc.tmp"
    mv -f "${tgtdir}/.bashrc.tmp" "${tgtdir}/.bashrc"
else
    echo "WARN: /etc/skel/.bashrc not readable; not rewriting ~/.bashrc"
fi

echo "INFO: setup \"${profile}\" finished"
