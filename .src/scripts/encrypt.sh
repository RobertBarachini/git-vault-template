#!/bin/bash

# Move to the project root using script's absolute path then operate on relative paths
function move_to_project_root() {
	local script_dir="$(dirname "$(readlink -f "$0")")"
	
	cd "$script_dir/../.." # adjust the path to the project root as needed
}

# Create a tarball of the vault directory
function create_archive() {
	tar -czf vault.tar.gz vault
	if [ $? -ne 0 ]; then
		echo "Failed to create the archive"
		exit 1
	fi
}

# Encrypt the archive using AES-256-CTR
function encrypt() {
	openssl enc -aes-256-ctr -salt -pbkdf2 -in vault.tar.gz -out vault.enc -pass file:./.key
}

function cleanup() {
	if [ -f vault.tar.gz ]; then
		rm vault.tar.gz
	fi
}

function main() {
	move_to_project_root

	create_archive

	encrypt
	encryption_status=$?

	cleanup

	# Check if the encryption was successful
	if [ $encryption_status -eq 0 ]; then
		echo "Encryption successful"
	else
		echo "Encryption failed"
		exit 1
	fi
}

main