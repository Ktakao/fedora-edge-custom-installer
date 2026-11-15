#!/bin/bash
set -eu
systemctl enable sshd.service NetworkManager.service init-persist.service save-grub-rootfs.service ntptime-sync.service
