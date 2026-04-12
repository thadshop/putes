#export DISPLAY=:0

#PS1="\[\e]0;\w\a\]\n\[\e[32m\]\u@\h:\[\e[33m\]\w\[\e[0m\]\n\s-\v\$ "
#PS1='\[\e]0;\u@\h:\w\a\]\n\[\e[32m\]\u@\h:\[\e[33m\]\w\[\e[0m\]\n\s-\v$ '
#PS1=\[\e]0;\u@\h: \w\a\]${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$
PS1='\[\e]0;\u@\h: \w\a\]${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\n\s-\v$ '
export VISUAL='vi'
export EDITOR='vi'
export PAGER='less'

export TEVENT_LOG="${HOME}/log/tevent.log"
export SSH_AGENT_ENV="${HOME}/.ssh/ssh-agent.env"

export PYTHONPATH="${HOME}/opt/python"
export PYENV_ROOT="${HOME}/.pyenv"
[[ -d ${PYENV_ROOT}/bin ]] && export PATH="${PYENV_ROOT}/bin:${PATH}"

eval "$(pyenv init --path)"
eval "$(pyenv init -)"

set -o vi
