# Thad's stuff below
if [[ "${-}" == *i* ]]; then #do Thad's setup for interactive shell
    echo -e "$(date)\t####-->> Starting  Thad's additions to .bashrc <<--####" | tee -a /home/thad/log/tevent.log | cut -f2-
    source "${HOME}/etc/tbashrc"
    source "${HOME}/etc/handle_ssh-agent.source.sh"
    echo -e "$(date)\t####-->> Done with Thad's additions to .bashrc <<--####" | tee -a /home/thad/log/tevent.log | cut -f2-
fi
# Thad's stuff above
