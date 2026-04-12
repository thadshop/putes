alias cscratch='cd ~/Scratch'
#alias vi='vim'
alias less='less -X'

# try to make bash like ksh
alias whence='type'
alias e='fc -e vi'

# General Unix stuff
#alias ls='ls' # by default, Bash seems to alias ls='ls -F'; thanks, but no thanks!
#alias ll='ls -al'
#alias lll='ls -altr'
alias lsd='ls -al | grep ^d'
#alias lsfiles='ls -al | grep -v ^d'
alias hist='history'

# Miscellaneous stuff
alias prdts='date "+%Y-%m-%d_%H-%M-%S"'
alias pyvenv='source ~/opt/pyvenv/bin/activate'
alias snas='ssh root@readynas-anders'
alias gopho='ssh -p 8022 u0_a478@192.168.1.245'
