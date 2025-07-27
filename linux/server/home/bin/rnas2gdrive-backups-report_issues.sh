#!/usr/bin/env bash

HUSH=true
reportFile="${HOME}/log/rnas2gdrive-backups-issues_report.txt"
function sendm {
    "${HOME}/bin/pysendm" "${@}"
}
mailTo='thadshop@gmail.com'
echo "STARTING $(basename "${0}") at $(date)"
/home/thad/bin/rnas2gdrive-backups-check.sh > "${reportFile}" 2>&1
# I want to find ': 0 differences found' in the report; if not there are issues
if [[ -z $(/usr/bin/egrep ': 0 differences found$' "${reportFile}") ]]; then
    echo 'vvvvv differences were found, output from check below vvvvv'
    /usr/bin/cat "${reportFile}"
    echo '^^^^^ differences were found, output from check above ^^^^^'
    echo "sending above output to ${mailTo}"
    sendm "${mailTo}" 'Issues in backup of rNAS to Gdrive' "$(/usr/bin/cat "${reportFile}")"
else
    echo 'no differences were found'
    sendm "${mailTo}" 'FYI: things look good in backup of rNAS to Gdrive' "$(/usr/bin/cat "${reportFile}")"
fi
echo "ENDING   $(basename "${0}") at $(date)"
