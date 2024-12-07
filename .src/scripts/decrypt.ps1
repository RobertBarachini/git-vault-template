# This script assumes tar and openssl are available on Windows
function Move-ToProjectRoot {
	$scriptDir = Split-Path -Path $PSCommandPath -Parent
	Set-Location -Path (Join-Path $scriptDir "..\..") # Adjust to your project root as needed
}

function Has-Changes {
	if (-Not (Test-Path "vault")) {
			return $false
	}

	Set-Location -Path "vault"

	# If .git directory doesn't exist, assume no changes
	if (-Not (Test-Path ".git")) {
			Set-Location -Path ..
			return $false
	}

	# Check if there are any changes in the repository using git status
	$changes = git status --porcelain
	Set-Location -Path ..
	return -Not [string]::IsNullOrWhiteSpace($changes)
}

function Decrypt {
	openssl enc -d -aes-256-ctr -salt -pbkdf2 -in "vault.enc" -out "vault.tar.gz" -pass file:"./.key"

	if ($LASTEXITCODE -ne 0) {
			Write-Host "Decryption failed"
			exit 1
	}
}

function Extract-Archive {
	if (-Not (Test-Path "vault.tar.gz")) {
			Write-Host "Archive not found"
			exit 1
	}

	$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
	$hasChanges = Has-Changes

	if ($hasChanges) {
			Write-Host "There are changes in the vault repository - moving vault contents to '.old/vault-$timestamp'"
			$backupPath = ".old/vault-$timestamp"
			New-Item -ItemType Directory -Path $backupPath -Force > $null
			Move-Item -Path "vault\*" -Destination $backupPath -Force
	}

	if (Test-Path "vault") {
			Remove-Item -Path "vault" -Recurse -Force
	}

	tar -xzf "vault.tar.gz" "vault"

	if ($LASTEXITCODE -ne 0) {
			Write-Host "Extraction failed"
			exit 1
	}

	if ($hasChanges) {
			Write-Host "Syncing local changes back to latest vault"
			robocopy ".old/vault-$timestamp" "vault" /MIR /XD .git > $null
	}

	Write-Host "Vault has been successfully decrypted"
}

function Cleanup {
	if (Test-Path "vault.tar.gz") {
			Remove-Item -Path "vault.tar.gz" -Force
	}
}

function Main {
	Move-ToProjectRoot
	Decrypt
	Extract-Archive
	Cleanup
}

Main
