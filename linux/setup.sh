#!/usr/bin/env bash
# Deploy putes home files: always applies linux/base/home, then linux/<workstation|server>/home.
# Not on PATH; run from your clone, e.g. ./linux/setup.sh workstation
# Requires: bash, cp, mkdir, chmod, cat, mv; optional: git for tracked-file listing.

DRY_RUN=''
UNTRACKED='ask'   # ask | include | exclude
profile=''

while [[ $# -gt 0 ]]; do
    case "${1}" in
        -n | --dry-run )
            DRY_RUN=1
            shift
            ;;
        --untracked=* )
            UNTRACKED="${1#--untracked=}"
            case "${UNTRACKED}" in
                ask | include | exclude ) ;;
                * )
                    echo "ERROR: --untracked must be ask, include, or exclude" >&2
                    exit 1
                    ;;
            esac
            shift
            ;;
        workstation | server )
            profile="${1}"
            shift
            ;;
        * )
            echo "ERROR: usage: ${0##*/} [-n|--dry-run] [--untracked=ask|include|exclude] workstation|server" >&2
            exit 1
            ;;
    esac
done

if [[ -z "${profile}" ]]; then
    echo "ERROR: usage: ${0##*/} [-n|--dry-run] [--untracked=ask|include|exclude] workstation|server" >&2
    exit 1
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tgtdir="${HOME}"
base_home="${script_dir}/base/home"
prof_home="${script_dir}/${profile}/home"
reporoot="$(git -C "${script_dir}" rev-parse --show-toplevel 2>/dev/null)" || reporoot=''

HOME_LAYOUT_DIR_MODE='775'
DOT_BEFORE="${script_dir}/base/bashrc.dotfile.before-skel.bash"
DOT_AFTER="${script_dir}/base/bashrc.dotfile.after-skel.bash"

run_cmd() {
    if [[ -n "${DRY_RUN}" ]]; then
        echo "DRY RUN: $*"
    else
        "$@"
    fi
}

# Write dst from one or more source files (cat src... > dst), or from stdin if no sources given.
write_file() {
    local dst="${1}"; shift
    if [[ -n "${DRY_RUN}" ]]; then
        if [[ $# -gt 0 ]]; then
            echo "DRY RUN: write \"${dst}\" from: $*"
        else
            echo "DRY RUN: write \"${dst}\""
        fi
    else
        if [[ $# -gt 0 ]]; then
            cat "$@" > "${dst}"
        else
            cat > "${dst}"
        fi
    fi
}

# Paths under etc/bash/rc/*.bash are assembled by assemble_etc_bash_rc — not copied verbatim.
# Other names under etc/bash/rc/ (e.g. README.txt) are copied normally by deploy_home_tree.
skip_home_deploy_rel() {
    local rel="${1}"
    [[ "${rel}" == etc/bash/rc/*.bash ]]
}

ensure_home_rel_dir() {
    local rel="${1}"
    [[ -z "${rel}" || "${rel}" == '.' ]] && return 0
    rel="${rel#/}"
    rel="${rel%/}"
    [[ -z "${rel}" ]] && return 0
    run_cmd mkdir -p "${tgtdir}/${rel}"
    local cur="${tgtdir}"
    local rest="${rel}"
    local part
    while [[ -n "${rest}" ]]; do
        part="${rest%%/*}"
        rest="${rest#"${part}"}"
        rest="${rest#/}"
        cur="${cur}/${part}"
        run_cmd chmod "${HOME_LAYOUT_DIR_MODE}" "${cur}"
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
        run_cmd cp "${local_src}" "${local_tgt}"
        run_cmd chmod 775 "${local_tgt}"
    else
        echo "cp; chmod 664: \"${local_src}\" \"${local_tgt}\""
        run_cmd cp "${local_src}" "${local_tgt}"
        run_cmd chmod 664 "${local_tgt}"
    fi
}

# Prompt user about untracked files; sets include_untracked=1 or returns 1 to abort.
prompt_untracked() {
    local label="${1}"; shift
    local paths=("$@")

    echo "WARN: ${label}: found ${#paths[@]} untracked file(s):"
    local p
    for p in "${paths[@]}"; do
        echo "  ${p}"
    done

    while true; do
        printf "Include untracked files for %s? [i=include, e=exclude, a=abort]: " "${label}"
        local reply
        read -r reply </dev/tty
        case "${reply}" in
            i | include ) return 0 ;;
            e | exclude ) return 1 ;;
            a | abort   ) echo "INFO: aborted by user" >&2; exit 1 ;;
            * ) echo "  Please enter i, e, or a." ;;
        esac
    done
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

        # Check for untracked files under this prefix.
        local -a untracked_paths=()
        while IFS= read -r -d '' path; do
            untracked_paths+=("${path}")
        done < <(git -C "${reporoot}" ls-files -z --others --exclude-standard "${git_prefix}" 2>/dev/null || true)

        if [[ ${#untracked_paths[@]} -gt 0 ]]; then
            local include_untracked=''
            case "${UNTRACKED}" in
                include )
                    echo "INFO: ${label}: including ${#untracked_paths[@]} untracked file(s) (--untracked=include)"
                    include_untracked=1
                    ;;
                exclude )
                    echo "INFO: ${label}: skipping ${#untracked_paths[@]} untracked file(s) (--untracked=exclude)"
                    ;;
                ask )
                    prompt_untracked "${label}" "${untracked_paths[@]}" && include_untracked=1
                    ;;
            esac

            if [[ -n "${include_untracked}" ]]; then
                for path in "${untracked_paths[@]}"; do
                    local rel="${path#"${git_prefix}/"}"
                    copy_one_home_file "${rel}" "${reporoot}/${path}"
                    copy_n=$((copy_n + 1))
                done
            fi
        fi
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

# Remove ~/etc/bash/rc/*.bash that are no longer defined under base/home/etc/bash/rc/.
# Run before assemble_etc_bash_rc so stale names are cleared, then assembly writes only current fragments.
# Renames (e.g. functions.bash -> 30.functions.bash) leave stale files; ~/.bashrc sources
# all *.bash, so leftovers still run and can duplicate side effects.
prune_obsolete_etc_bash_rc() {
    local -a base_files=("${base_home}/etc/bash/rc/"*.bash)
    local -A expected=()
    local f name had_nullglob

    if [[ ! -f "${base_files[0]}" ]]; then
        echo "ERROR: no *.bash files found in \"${base_home}/etc/bash/rc\"" >&2
        exit 1
    fi

    for f in "${base_files[@]}"; do
        [[ -f "${f}" ]] || continue
        expected["${f##*/}"]=1
    done

    run_cmd mkdir -p "${tgtdir}/etc/bash/rc"

    had_nullglob=0
    shopt -q nullglob && had_nullglob=1
    shopt -s nullglob
    for f in "${tgtdir}/etc/bash/rc/"*.bash; do
        name="${f##*/}"
        [[ -n "${expected[${name}]}" ]] && continue
        echo "INFO: removing obsolete etc/bash/rc fragment \"${f}\" (not in linux/base/home/etc/bash/rc/)"
        run_cmd rm -f "${f}"
    done
    [[ "${had_nullglob}" -eq 0 ]] && shopt -u nullglob
}

# cat base fragment > ~/etc/bash/rc/<name>.bash; cat profile fragment >> same (if present).
# Files are discovered from base/etc/bash/rc/*.bash in lexical order (numeric prefix controls sequence).
# Each fragment is preceded by a comment identifying its source in the repo.
assemble_etc_bash_rc() {
    local base_f prof_f out srcs name src rel_src

    run_cmd mkdir -p "${tgtdir}/etc/bash/rc"
    local -a base_files=("${base_home}/etc/bash/rc/"*.bash)
    if [[ ! -f "${base_files[0]}" ]]; then
        echo "ERROR: no *.bash files found in \"${base_home}/etc/bash/rc\"" >&2
        exit 1
    fi

    for base_f in "${base_files[@]}"; do
        name="${base_f##*/}"
        prof_f="${prof_home}/etc/bash/rc/${name}"
        out="${tgtdir}/etc/bash/rc/${name}"
        srcs=("${base_f}")
        [[ -f "${prof_f}" ]] && srcs+=("${prof_f}")
        if [[ -n "${DRY_RUN}" ]]; then
            echo "DRY RUN: write \"${out}\" from: ${srcs[*]}"
        else
            : > "${out}"
            for src in "${srcs[@]}"; do
                if [[ -n "${reporoot}" ]]; then
                    rel_src="putes:${src#"${reporoot}/"}"
                else
                    rel_src="${src}"
                fi
                cat >> "${out}" <<EndOfHereDoc

#
# BEWARE OF EDITING THIS FILE DIRECTLY
#
# It is generated by putes:linux/setup.sh
# To change it, edit the source files and run setup.sh
#
# below should have come directly from ${rel_src}
#

EndOfHereDoc
                cat "${src}" >> "${out}"
            done
            chmod 644 "${out}"
        fi
        echo "INFO: assembled \"${out}\""
    done
}

if [[ ! -d "${tgtdir}" ]]; then
    echo "ERROR: HOME not a directory: ${tgtdir}" >&2
    exit 1
fi

[[ -n "${DRY_RUN}" ]] && echo "INFO: DRY RUN — no files will be modified"
echo "INFO: putes setup profile=\"${profile}\"; target \"${tgtdir}\""

deploy_home_tree "base" "${base_home}" "linux/base/home"
deploy_home_tree "${profile}" "${prof_home}" "linux/${profile}/home"

prune_obsolete_etc_bash_rc
assemble_etc_bash_rc

# ~/.bashrc: optional comment snippets (repo) + /etc/skel + optional + source ~/etc/bash/rc/*.bash
if [[ -r /etc/skel/.bashrc ]]; then
    echo "INFO: writing \"${tgtdir}/.bashrc\" from /etc/skel/.bashrc + ~/etc/bash/rc/*.bash"
    if [[ -n "${DRY_RUN}" ]]; then
        echo "DRY RUN: write \"${tgtdir}/.bashrc\""
    else
        {
            [[ -r "${DOT_BEFORE}" ]] && cat "${DOT_BEFORE}"
            cat /etc/skel/.bashrc
            [[ -r "${DOT_AFTER}" ]] && cat "${DOT_AFTER}"
        } > "${tgtdir}/.bashrc.tmp"
        chmod 644 "${tgtdir}/.bashrc.tmp"
        mv -f "${tgtdir}/.bashrc.tmp" "${tgtdir}/.bashrc"
    fi
else
    echo "WARN: /etc/skel/.bashrc not readable; not rewriting ~/.bashrc"
fi

echo "INFO: setup \"${profile}\" finished"
