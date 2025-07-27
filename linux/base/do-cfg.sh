#!/usr/bin/env bash

# make directories
while read d; do
    echo "mkdir -p; chmod 775: \"${HOME}/${d}\""
    mkdir -p "${HOME}/${d}"
    chmod 775 "${HOME}/${d}"
done < $(dirname ${0})/mkdirs.cfg

# copy executable files
while read f; do
    echo "cp; chmod 775: \"$(dirname ${0})/home/${f}\" \"${HOME}/${f}\""
    cp "$(dirname ${0})/home/${f}" "${HOME}/${f}"
    chmod 775 "${HOME}/${f}"
done < $(dirname ${0})/copies-exe.cfg

# copy regular files
while read f; do
    echo "cp; chmod 664: \"$(dirname ${0})/home/${f}\" \"${HOME}/${f}\""
    cp "$(dirname ${0})/home/${f}" "${HOME}/${f}"
    chmod 664 "${HOME}/${f}"
done < $(dirname ${0})/copies-reg.cfg

# make symlinks
cat $(dirname ${0})/links-sh.cfg
source $(dirname ${0})/links-sh.cfg
