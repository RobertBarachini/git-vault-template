# Introduction

This repository is a template for creating low-dependency, encrypted, nested Git repositories to securely share versioned configuration files, secrets, and other data across machines and development environments.

Currently fully functional on Linux and MacOS, and Windows.

## Details

It enables versioned secret management within a Git repository, with the following characteristics:

- Perfect for enabling easier and more secure sharing of secrets and configuration files between team members, CI/CD pipelines, and development environments.
- Shared secrets, configs, ..., which are stored in a repository are compressed using `tar` and encrypted using `openssl` (AES-256-CTR) before being committed to the repository.
- The encryption key needed to decrypt the vault is shared using a secure method (e.g. password manager) and stored in the system's credential manager (TODO: currently it is stored in a file).
- The vault can be decrypted and extracted on any machine with the encryption key.
- Cross-platform compatibility (Linux, MacOS, Windows).
- Low dependency - only `git`, `openssl`, `tar`, and `rsync` / `robocopy` (OS specific) are required, most of which are pre-installed on most systems and may not need to be installed separately.
- Low maintenance - the vault is self-contained and can be easily moved or backed up. The workflow is generic and automated using Git hooks - set and forget.
- Low footprint - the vault is tarred, gzipped, and encrypted in a single file, which can be easily shared or stored in a cloud service.
- Secure - the vault is encrypted using a strong encryption algorithm and the encryption key is stored separately, and securely. Even if a malicious actor gains access to Git and the encrypted vault, they would still need the encryption key to decrypt it.
- Versioned - the vault is a Git repository (advised), which makes it easier to track changes and revert to previous versions if necessary.
- Integrated with Git hooks - the vault is automatically encrypted when changes are committed within the vault and decrypted when changes are pulled or checked out from the root repository.
- Conflicting local changes are synced to latest version of the vault. If conflicts are found, the local version is also copied to `.old` directory for manual inspection if rsync or any other step fails.

> NOTE: Instructions assume that you are running any commands from the root directory of the repository unless otherwise specified.

> NOTE: Scripts within the vault may not retain proper permissions if the vault is copied to a Windows machine. This is a known issue and may be addressed in the future (custom permission lists). To avoid messing up Linux file permissions on Windows, run `git config core.fileMode false` in the main and vault repositories on Windows.

# Template setup

## Test out the template

1. Clone this repository to your local machine.
2. Open project in your favorite editor (VS Code is recommended for ease of use).
3. Create `.key` file by running `echo -n 'unsafe-key' > .key` (not recommended for production).
4. Run `./.src/scripts/decrypt.sh` to decrypt the vault. You may need to modify file permissions depending on your system. UNIX example: `chmod +x ./.src/scripts/decrypt.sh`.
5. Inspect the contents of the `vault` directory. Use Git commands to track changes and commit new files or inspect the history. VS Code integrated Git tools and extensions are recommended for viewing the Git history and changes between commits.

> NOTE: For the IDE to detect and properly display the Git history of the newly created vault folder, you may need to reload or restart the IDE.

## Set up a new repository

1. Clone this repository to your local machine.
2. Run `rm -rf .git` to remove the Git history.
3. Run `git init -b main` to initialize a new Git repository.
4. Delete any files you don't need (such as the `.vscode` directory).
5. Create a strong `.key` file by running `openssl rand 4096 | openssl enc -base64 -A > .key` or `gpg --gen-random --armor 1 4096 > .key` in the root directory.
6. Delete old encrypted vault by running `rm vault.enc`.
7. Create a new vault folder by running `mkdir vault`.
8. Init the vault by running `git init -b vault vault`.
9. Add a one-liner `README.md` to the vault by running `echo '# Vault' > vault/README.md`.
10. Commit the changes by running `git add . && git commit -m 'Init vault'`.
11. Encrypt the vault by running `./.src/scripts/encrypt.sh`.
12. Commit any initial files needed for repository functionality then commit the encrypted vault by running `git add vault.enc && git commit -m 'Init vault'`. Root repository should have commits indicative of the changes in the vault. It is best to copy them when making changes to the vault to keep track of the changes, as encrypted vault's git history is not visible at rest (on the remote). Make sure to omit any sensitive information from the commit messages.
13. Push the changes to the remote repository by running `git push origin main`.
14. Share the `.key` file with the team members or on deployment infrastructure using a secure method (e.g. password manager).

# Workflow

This assumes that the vault is set up and the encryption key is shared with the team members or on deployment infrastructure.

To improve ease of use, you can automate encryption and decryption by using Git hooks.

Make changes within the vault and commit them as you would with a regular Git repository. The vault will be automatically encrypted when changes are committed within the vault. Commit the `vault.enc` file in the root repository and push the changes to the remote repository.

When changes are pulled or checked out from the root repository, the vault will be automatically decrypted.

If you opted for not using Git hooks, you can manually decrypt the vault by running `./.src/scripts/decrypt.sh` and encrypt the vault by running `./.src/scripts/encrypt.sh` (or `powershell.exe -NoProfile -ExecutionPolicy Bypass -File ./.src/scripts/encrypt.ps1` on Windows).

## Git hooks

These ensure that the vault encryption and decryption lifecycle is seamless and transparent to the user.

Git hook logs can be inspected in VS Code by opening the Output panel and selecting Git from the dropdown menu.

### Autotically decrypt the vault (post-merge hook)

Ensure that the encrypted vault file is decrypted after every pull or checkout from the root repository by setting up a `post-merge` hook within the root repository by running the following commands:

```sh
# Post-merge hook within the root repository (main)
mkdir -p .git/hooks # Windows: mkdir .git\hooks
touch .git/hooks/post-merge # Windows: type nul > .git\hooks\post-merge
chmod +x .git/hooks/post-merge # Windows: attrib +x .git\hooks\post-merge or may not be necessary
```

Add the following code to the `post-merge` hook:

> NOTE: Some IDEs may hide the .git directory. If you are not comfortable with the command line, you can use the file explorer or if you are using VS Code, you can edit the `.vscode/settings.json` file to show hidden files and directories by adding `"files.exclude": {".git": false}`.

```sh
#!/bin/bash
echo "RUNNING POST-MERGE HOOK IN VAULT"
pwd
# Determine the OS
if [[ "$(uname -s)" == "Linux" || "$(uname -s)" == "Darwin" ]]; then
	# UNIX-like systems (Linux, macOS)
	echo "Decrypting files using the decrypt.sh script"
	.src/scripts/decrypt.sh
	exit $?
elif [[ "$(uname -s)" =~ ^CYGWIN|MINGW|MSYS ]]; then
	# Windows systems
	echo "Decrypting files using the decrypt.ps1 script"
	powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".src/scripts/decrypt.ps1"
	exit $?
else
	echo "Unsupported OS: $(uname -s)"
	exit 1
fi
```

### Automatically encrypt the vault (post-commit hook)

Ensure that the encrypted vault file is created after every commit inside the vault's Git repository by running the following commands:

> NOTE: You may not need to do this if the hook is already set up within the vault. Verify that the `post-commit` hook is set up within the vault repository by running `cat vault/.git/hooks/post-commit`.

```sh
# Post-commit hook within the vault repository (vault)
mkdir -p vault/.git/hooks
touch vault/.git/hooks/post-commit
chmod +x vault/.git/hooks/post-commit
```

Add the following code to the `post-commit` hook:

```sh
#!/bin/bash
echo "RUNNING POST-COMMIT HOOK IN VAULT"
pwd
# Determine the OS
if [[ "$(uname -s)" == "Linux" || "$(uname -s)" == "Darwin" ]]; then
	# UNIX-like systems (Linux, macOS)
	echo "Encrypting files using the encrypt.sh script"
	../.src/scripts/encrypt.sh
	exit $?
elif [[ "$(uname -s)" =~ ^CYGWIN|MINGW|MSYS ]]; then
	# Windows systems
	echo "Encrypting files using the encrypt.ps1 script"
	powershell.exe -NoProfile -ExecutionPolicy Bypass -File "../.src/scripts/encrypt.ps1"
	exit $?
else
	echo "Unsupported OS: $(uname -s)"
	exit 1
fi
```

# TODO

- Create a workflow to set a config file with filepaths and their permissions (Windows wipes out permissions when copying files, add them back if necessary as a post-process)
- Create a template initialization script that sets up the repository with the necessary files and folders from scratch
- Use system credential manager to store the encryption key
- Maintenance scripts (clear git history, ...)

# DONE

- Check cross-platform collaboration compatibility
- Create Windows scripts (check if git bash works out of the box and openssl and tar are installed, use robocopy instead of rsync) -> Git bash relies on WSL... Created `decrypt.ps1` and `encrypt.ps1` scripts instead. Tar and openssl worked out of the box. Robocopy is used instead of rsync.
- Write README.md
- Adapt local code to the template
