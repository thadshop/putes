#   The point of this script is to get an interactive login shell to a state where:
#     1) An ssh-agent is running, and
#     2) the environment variables SSH_AGENT_PID and SSH_AUTH_SOCK have been automatically set accordinly, and
#     3) the identity has been added to the agent.
#   The echo statements narrate how it gets there.

[[ -f ${TEVENT_LOG} && -w ${TEVENT_LOG} ]] || TEVENT_LOG=/dev/null
[[ -n ${SSH_AGENT_ENV} ]] || SSH_AGENT_ENV="${HOME}/.ssh/ssh-agent.env"
[[ ${HUSH} ]] && OUTPUT='/dev/null' || OUTPUT='/dev/stdout'

if [[ -d $(dirname "${SSH_AGENT_ENV}") && -O $(dirname "${SSH_AGENT_ENV}") \
  && -r $(dirname "${SSH_AGENT_ENV}") && -w $(dirname "${SSH_AGENT_ENV}") && -x $(dirname "${SSH_AGENT_ENV}") ]] \
  && touch "${SSH_AGENT_ENV}" && chmod 600 "${SSH_AGENT_ENV}" \
  && [[ -f ${SSH_AGENT_ENV} && -O ${SSH_AGENT_ENV} && -r ${SSH_AGENT_ENV} && -w ${SSH_AGENT_ENV} ]]; then
    if [[ $(egrep '^SSH_(AUTH_SOCK|AGENT_PID)=.+;\sexport\sSSH_(AUTH_SOCK|AGENT_PID);$' "${SSH_AGENT_ENV}" | wc -l) \
      -eq $(cat "${SSH_AGENT_ENV}" | wc -l) ]]; then
        echo -e "$(date)\t[handle_ssh-agent%${$}] agent file satisfactory, sourcing it {${SSH_AGENT_ENV}}:" \
          | tee -a "${TEVENT_LOG}" | cut -f2- > "${OUTPUT}"
        cat "${SSH_AGENT_ENV}" | while read log_str; do
            echo -e "$(date)\t[handle_ssh-agent%${$}] ${log_str}" | tee -a "${TEVENT_LOG}" | cut -f2- > "${OUTPUT}"
        done
        source "${SSH_AGENT_ENV}"
        if [[ -n $(pgrep -u $(whoami) -f '^/usr/bin/ssh-agent\s*' | grep "^${SSH_AGENT_PID}\$") \
          && -O ${SSH_AUTH_SOCK} && -S ${SSH_AUTH_SOCK} && -r ${SSH_AUTH_SOCK} && -w ${SSH_AUTH_SOCK} ]]; then
            echo -e "$(date)\t[handle_ssh-agent%${$}] agent artifacts satisfactory, adding identity" \
              | tee -a "${TEVENT_LOG}" | cut -f2- > "${OUTPUT}"
            /usr/bin/ssh-add 2>&1 | while read log_str; do
                echo -e "$(date)\t[handle_ssh-agent%${$}] ${log_str}" | tee -a "${TEVENT_LOG}" | cut -f2- > "${OUTPUT}"
            done
            if [[ ${PIPESTATUS} -eq 0 ]]; then
                echo -e "$(date)\t[handle_ssh-agent%${$}] writing to SSH_AGENT_ENV={${SSH_AGENT_ENV}}:" \
                 | tee -a "${TEVENT_LOG}" | cut -f2- > "${OUTPUT}"
                echo "SSH_AUTH_SOCK=${SSH_AUTH_SOCK}; export SSH_AUTH_SOCK;" > "${SSH_AGENT_ENV}"
                echo "SSH_AGENT_PID=${SSH_AGENT_PID}; export SSH_AGENT_PID;" >> "${SSH_AGENT_ENV}"
                cat "${SSH_AGENT_ENV}" | while read log_str; do
                    echo -e "$(date)\t[handle_ssh-agent%${$}] ${log_str}" | tee -a "${TEVENT_LOG}" \
                      | cut -f2- > "${OUTPUT}"
                done
            else
                echo -e "$(date)\t[handle_ssh-agent%${$}] unsatisfactory add, starting agent," \
                  "writing to SSH_AGENT_ENV={${SSH_AGENT_ENV}} and sourcing it:" | tee -a "${TEVENT_LOG}" \
                  | cut -f2- > "${OUTPUT}"
                /usr/bin/ssh-agent | egrep -v '^echo Agent pid [0-9]+;$' | tee "${SSH_AGENT_ENV}" \
                  | while read log_str; do
                    echo -e "$(date)\t[handle_ssh-agent%${$}] ${log_str}" | tee -a "${TEVENT_LOG}" \
                      | cut -f2- > "${OUTPUT}"
                done
                source "${SSH_AGENT_ENV}"
                /usr/bin/ssh-add 2>&1 | while read log_str; do
                    echo -e "$(date)\t[handle_ssh-agent%${$}] ${log_str}" | tee -a "${TEVENT_LOG}" \
                      | cut -f2- > "${OUTPUT}"
                done
                [[ ${PIPESTATUS} -eq 0 ]] || false
            fi
        else
            echo -e "$(date)\t[handle_ssh-agent%${$}] unsatisfactory agent artifacts, starting agent," \
              "writing to SSH_AGENT_ENV={${SSH_AGENT_ENV}} and sourcing it:" | tee -a "${TEVENT_LOG}" \
              | cut -f2- > "${OUTPUT}"
            /usr/bin/ssh-agent | egrep -v '^echo Agent pid [0-9]+;$' | tee "${SSH_AGENT_ENV}" \
              | while read log_str; do
                echo -e "$(date)\t[handle_ssh-agent%${$}] ${log_str}" | tee -a "${TEVENT_LOG}" | cut -f2- > "${OUTPUT}"
            done
            source "${SSH_AGENT_ENV}"
            /usr/bin/ssh-add 2>&1 | while read log_str; do
                echo -e "$(date)\t[handle_ssh-agent%${$}] ${log_str}" | tee -a "${TEVENT_LOG}" | cut -f2- > "${OUTPUT}"
            done
            [[ ${PIPESTATUS} -eq 0 ]] || false
        fi
    else
        echo -e "$(date)\t[handle_ssh-agent%${$}] unsatisfactory agent file {${SSH_AGENT_ENV}}, starting agent," \
          "writing to SSH_AGENT_ENV={${SSH_AGENT_ENV}} and sourcing it:" | tee -a "${TEVENT_LOG}" \
          | cut -f2- > "${OUTPUT}"
        /usr/bin/ssh-agent | egrep -v '^echo Agent pid [0-9]+;$' | tee "${SSH_AGENT_ENV}" \
          | while read log_str; do
            echo -e "$(date)\t[handle_ssh-agent%${$}] ${log_str}" | tee -a "${TEVENT_LOG}" | cut -f2- > "${OUTPUT}"
        done
        source "${SSH_AGENT_ENV}"
        /usr/bin/ssh-add 2>&1 | while read log_str; do
            echo -e "$(date)\t[handle_ssh-agent%${$}] ${log_str}" | tee -a "${TEVENT_LOG}" | cut -f2- > "${OUTPUT}"
        done
        [[ ${PIPESTATUS} -eq 0 ]] || false
    fi
else
    echo -e "$(date)\t[handle_ssh-agent%${$}] unable to establish satisfactory agent file {${SSH_AGENT_ENV}}" \
      | tee -a "${TEVENT_LOG}" | cut -f2- > "${OUTPUT}"
    false
fi
