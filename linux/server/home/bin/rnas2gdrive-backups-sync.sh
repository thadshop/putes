#!/usr/bin/env bash

echo "STARTING $(basename "${0}") at $(date)"
rclone sync --dry-run /mnt/rnas/Thad/Backups/ gdrive-thadshop:backups/ReadyNAS-anders/data/Thad/Backups/
#rclone sync           /mnt/rnas/Thad/Backups/ gdrive-thadshop:backups/ReadyNAS-anders/data/Thad/Backups/
echo "ENDING   $(basename "${0}") at $(date)"

