#!/usr/bin/env bash

echo "STARTING $(basename "${0}") at $(date)"
#rclone sync --dry-run /mnt/rnas/Thad/Media/ gdrive-thadshop:backups/Media/
rclone sync --stats-log-level INFO /mnt/rnas/Thad/Media/ gdrive-thadshop:backups/Media/
echo "ENDING   $(basename "${0}") at $(date)"

