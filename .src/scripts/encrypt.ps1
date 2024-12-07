# Move to the project root using the script's absolute path
function Move-ToProjectRoot {
	$scriptDir = Split-Path -Path $PSCommandPath -Parent
	Set-Location -Path (Join-Path $scriptDir "..\..") # Adjust to your project root as needed
}

# Create a tarball of the vault directory
function Create-Archive {
	tar -czf "vault.tar.gz" "vault"
	if ($LASTEXITCODE -ne 0) {
			Write-Host "Failed to create archive"
			exit 1
	}
}

# Encrypt the archive using AES-256-CTR
function Encrypt {
	openssl enc -aes-256-ctr -salt -pbkdf2 -in "vault.tar.gz" -out "vault.enc" -pass file:"./.key"
	return $LASTEXITCODE
}

# Cleanup temporary files
function Cleanup {
	if (Test-Path "vault.tar.gz") {
			Remove-Item -Path "vault.tar.gz" -Force
	}
}

# Main function to run the workflow
function Main {
	Move-ToProjectRoot

	Create-Archive

	$encryptionStatus = Encrypt

	Cleanup

	# Check if the encryption was successful
	if ($encryptionStatus -eq 0) {
			Write-Host "Encryption successful"
	} else {
			Write-Host "Encryption failed"
			exit 1
	}
}

Main
