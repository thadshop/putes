# This is Bash shell code sourced by:
#   ~/bin/buhome2rnas
#   (an older version of) ~/bin/synctoolbox

if [[ ! ${NO_PROMPT} ]]; then
    echo "Dry run, SOURCE=${SOURCE}"
    echo "Dry run, DEST=${DEST}"
    echo "Dry run, rsync options: ${RSYNC_OPTS}"
    rsync --dry-run ${RSYNC_OPTS} "${SOURCE}" "${DEST}"
    read -p "Enter 'Y' to proceed with the rsync, or anything else to quit: " PROCEED
    if [[ ${PROCEED} != 'Y' ]]; then
        echo 'Abandoning based on response.'
        exit 0
    fi
fi

# We will keep trying the rsync until either:
#   (a) we have all zero-values for number of files created, deleted, transfered, and their total size (i.e., nothing to sync, source and destination match), or
#   (b) we reach the maximum number of tries configured.
typeset -i tries=0
typeset -i sleep_increment_secs=2
if [[ ${MAX_TRIES} -gt 0 ]]; then
    finalMessage='WARNING: sync looks incomplete'
    while true; do
        ((tries++))
        if [[ ${tries} -ge 2 ]]; then
            sleep_secs=$(( ${sleep_increment_secs} * ((${tries} - 1)) ))
            echo -e "\nINFO: sleeping for ${sleep_secs} seconds, then going for try #${tries} of ${MAX_TRIES}, as the previous sync could be incomplete\n"
            sleep ${sleep_secs}
        fi
        rsync ${RSYNC_OPTS} --stats "${SOURCE}" "${DEST}" | tee -a "${TMPLOG}"
        if [[ -n $(egrep '^Number of created files: 0$' "${TMPLOG}") && -n $(egrep '^Number of deleted files: 0$' "${TMPLOG}") && -n $(egrep '^Number of regular files transferred: 0$' "${TMPLOG}") && -n $(egrep '^Total transferred file size: 0 bytes$' "${TMPLOG}") ]]; then
            finalMessage="INFO: sync looks complete after ${tries} tries"
            break
        fi
        if [[ ${tries} -ge ${MAX_TRIES} ]]; then
            finalMessage="INFO: stopping as the maximum number of tries (${MAX_TRIES}) was reached\n${finalMessage}"
            break
        fi
    done
    echo -e "\n${finalMessage}\n"
else
    echo -e "\nINFO: no sync was tried, because the maximum number of tries was set to ${MAX_TRIES}\n"
fi
