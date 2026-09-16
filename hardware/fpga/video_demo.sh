#!/bin/bash

# SPDX-FileCopyrightText: 2026 IObundle
#
# SPDX-License-Identifier: GPL-3.0-only

# Exit immediately if a command exits with a non-zero status
set -e

# Define target IP and credentials
TARGET_IP="192.168.74.2"
PASSWORD="root"

echo "------------------------------------------------"
echo "Running: ping -c 1 ${TARGET_IP}"
echo "------------------------------------------------"
ping -c 1 "${TARGET_IP}"

# Add a clean newline space
echo ""

echo "------------------------------------------------"
echo "Running: ssh root@${TARGET_IP} 'echo SSH connected successfully!; uname -a'"
echo "------------------------------------------------"

# Use env variable to avoid exposing password in process lists
export SSHPASS="${PASSWORD}"

sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@"${TARGET_IP}" 'echo "SSH connected successfully!"; uname -a'
