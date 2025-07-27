#!/usr/bin/env bash

echo "STARTING $(basename "${0}") at $(date)"
rclone check /mnt/rnas/Thad/Backups/ gdrive-thadshop:backups/ReadyNAS-anders/data/Thad/Backups/ --size-only --one-way
echo "ENDING   $(basename "${0}") at $(date)"

