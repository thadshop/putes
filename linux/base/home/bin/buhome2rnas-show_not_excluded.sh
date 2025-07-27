#!/usr/bin/env bash

comm -2 -3 <(ls -a1p "${HOME}" | sort) <(sort "${HOME}/etc/buhome2rnas-exclusions.txt")

