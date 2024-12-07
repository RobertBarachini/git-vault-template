#!/bin/bash

# This is duplicated from encrypt.sh which serves as the source of truth
# Sourcing functions from utility scripts is not used to keep the script self-contained
function move_to_project_root() {
	local script_dir="$(dirname "$(readlink -f "$0")")"
	cd "$script_dir/../.." # adjust the path to the project root as needed
}

function has_changes() {
	# If vault directory does not exist, we can safely assume that there are no changes
	if [ ! -d vault ]; then
		return 1
	fi

	cd vault
	
	# If the vault directory is not a git repository, assume no changes
	if [ ! -d .git ]; then
		cd ..
		return 1
	fi

	# Check if there are any changes in the repository using porcelain format and character count
	if [ $(git status --porcelain | wc -c) -eq 0 ]; then
		cd ..
		return 1
	fi

	cd ..
	return 0
}

function decrypt() {
	openssl enc -d -aes-256-ctr -salt -pbkdf2 -in vault.enc -out vault.tar.gz -pass file:./.key

	if [ $? -ne 0 ]; then
		echo "Decryption failed"
		exit 1
	fi
}

function extract_archive() {
	if [ ! -f vault.tar.gz ]; then
		echo "Archive not found"
		exit 1
	fi

	# Set a variable string from YYYY-MM-DD_HH-MM-SS
	local timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
	local has_changes_result=0

	has_changes
	has_changes_result=$?
	
	if [ $has_changes_result -eq 0 ]; then
		echo "There are changes in the vault repository - moving vault contents to '.old/vault-$timestamp'"

		mkdir -p .old/$timestamp

		mv vault ".old/vault-$timestamp"
	fi
	
	if [ -d vault ]; then
		rm -rf vault
	fi
	
	tar -xzf vault.tar.gz vault
	
	if [ $? -ne 0 ]; then
		echo "Extraction failed"
		exit 1
	fi

	if [ $has_changes_result -eq 0 ]; then
		echo "Syncing local changes back to latest vault"
		rsync -a --exclude='.git' ".old/vault-$timestamp" vault/
	fi

	# Run postscript
	if [ -f vault/.postscript.sh ]; then
		echo "Running postscript"
		local script_mode=$(stat -c %a vault/.postscript.sh)
		chmod +x vault/.postscript.sh
		./vault/.postscript.sh
		chmod $script_mode vault/.postscript.sh
	fi

	echo "Vault has been successfully decrypted"
}

function cleanup() {
	if [ -f vault.tar.gz ]; then
		rm vault.tar.gz
	fi
}

function main() {
	move_to_project_root

	decrypt

	extract_archive

	cleanup
}

main