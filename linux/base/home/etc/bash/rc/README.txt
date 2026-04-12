This directory is populated by putes:linux/setup.sh.

  *.bash   — assembled from putes:linux/base/home/etc/bash/rc/ and
             linux/<workstation|server>/home/etc/bash/rc/ fragments with the
             same basename; see that script for the merge rules.

             WARNING: setup.sh removes any *.bash file here whose name is not
             present under linux/base/home/etc/bash/rc/ in the putes repo (e.g.
             hand-added or leftover after a rename). Put one-off shell snippets
             elsewhere or add a fragment in putes.

  other    — copied as-is from those trees (not merged, not pruned).

Your shell sources every *.bash file here in lexical order; the loop lives in
putes:linux/base/bashrc.dotfile.after-skel.bash in the putes repo (appended when
setup.sh builds ~/.bashrc).
