eval "$(pyenv init --path)"
eval "$(pyenv init -)"

set -o vi

handle_ssh_agent

source "${HOME}/opt/util/keyring/init.bash"
