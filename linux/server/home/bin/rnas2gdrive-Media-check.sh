#!/usr/bin/env bash

echo "STARTING $(basename "${0}") at $(date)"
rclone check /mnt/rnas/Thad/Media/ gdrive-thadshop:/backups/Media/ --size-only --one-way
echo "ENDING   $(basename "${0}") at $(date)"

