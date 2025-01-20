# Introduction

This repository is a template for creating low-dependency, encrypted, nested Git repositories to securely share versioned configuration files, secrets, and other data across machines and development environments.

Currently fully functional on Linux and MacOS, and Windows.

Original repository (check if looking for updates): [git-vault-template](https://github.com/RobertBarachini/git-vault-template)

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

> NOTE: Files within the vault may not retain proper permissions if the vault is copied to a Windows machine. This is a known issue and may be addressed in the future (custom permission lists). Currently the best way to handle this is to ensure that files have `644` instead of `755` permissions. If you need to run further scripts outside of `vault/.postscript.sh` and track the changes without Windows wiping out permissions, just change their permissions to allow execution `chmod +x <some-executable>`, run them, and then change the permissions back by running `chmod 644 <some-executable>`. This has already been handled for `.postscript.sh` from within `decrypt.sh`. Define your custom workflows, such as copying of environment files to their destination, in this script. If your logic is "simple enough" you may get away by pointing `.postscript.ps1` to the `.postscript.sh` and keeping it as the source of truth. `decrypt.sh` and other files within the root repository don't need to be maintained this way as Git already tracks the executable bit in some contexts if `fileMode` is set to `true` in the Git configuration (default).

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
5. Create a strong `.key` file by running `openssl rand -base64 32 | tr -d '\n' > .key` on UNIX or `openssl rand -base64 32 | Out-File -FilePath .key -NoNewline` on Windows in the root directory. Additional command ensures that the newline character is not added to the file. This is important when sharing the key with others (via copy&paste), as the newline character may be copied along with the key and it can cause decryption issues - this is especially important on cross-platform collaboration as Windows uses different line endings (`\r\n`) than UNIX (`\n`).
6. Delete old encrypted vault by running `rm vault.enc`. Optionally you can keep the structure of the demo vault by decrypting it and copying the files to the new vault.
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

## Use cases and examples

Common use case for this vault repository is to store environment variables and share them securely between multiple developers or development environments (such as local development, CI/CD pipelines, staging, and production environments).

Many common public repositories include `.env` files or their templates in their respective repositories. This introduces many security risks and complicates development as keeping these files up to date manually and syncing them between team members can become a hassle. This project reduces the friction by providing a secure way to store and share these files either semi-manually or completely programmatically. All you need to do is to set up the vault once and share the encryption key with the team members (use a shared password manager for that). Other repositories can then reference the vault repository and its `.env` files in their workflows. How can this be achieved?

1. Set up the vault repository as described in the previous sections.
2. Use the `sample.env` file for example or create your own `.env` file in the vault repository (e.g. `vault/some_service.env`).
3. Programs, scripts, and services need to know where the vault folder is located to source the `.env` files. This can be achieved by setting an environment variable in the shell or in the CI/CD pipeline. Here are a few examples for different shells:

- **Bash**:

```sh
# Open the .bashrc file and add the following line
export MY_PROJECT_VAULT_PATH="/home/user/git/my-project/this-vault"
# Source the .bashrc file to apply the changes
source ~/.bashrc
```

- **Windows PowerShell**:

```ps1
# Open the $PROFILE file and add the following line
# you can open it by running `notepad $PROFILE`. If it doesn't exist, create it.
$env:MY_PROJECT_VAULT_PATH = "C:\Users\user\git\my-project\this-vault"
# Source the $PROFILE file to apply the changes
. $PROFILE
```

- **Zsh**:

```sh
# Open the .zshrc file and add the following line
export MY_PROJECT_VAULT_PATH="/home/user/git/my-project/this-vault"
# Source the .zshrc file to apply the changes
source ~/.zshrc
```

- **Fish**:

```sh
# Open the config.fish file and add the following line
set -x MY_PROJECT_VAULT_PATH "/home/user/git/my-project/this-vault"
# Source the config.fish file to apply the changes
source ~/.config/fish/config.fish
```

4. Create an environment variable sourcing workflow that suits you best. Following are a couple of examples for different programming languages / technologies.

> **Note:** Local development leverages the `local/` folder (located at this repository's root) for overriding the `.env` files in the vault. This is useful when you want to test changes locally or set up a specific configuration for your development environment (such as database connection strings, API keys, etc.) without affecting the shared vault or interrupting other team members. The `local/` folder is ignored by Git and is not tracked. You can create it and add your `.env` files there. Best practice is to create the same structure as in the vault folder to keep things consistent and only override the necessary values to reduce clutter.

> **Advice:** It is useful to specify the root of your project (`GIT_MY_PROJECT_PATH="..."`), the root of the external vault repository, like below examples (so you can still reference the vault and local folders separately), or the root of your GitLab group (`GIT_TOP_LEVEL_GROUP_NAME="..."` ; ensures you can reference as `$GIT_TOP_LEVEL_GROUP_NAME/vaults/development/vault/some_service.env`) when using the 'env variable pointer' strategy. This way you can easily reference multiple repositories by adding a single key to your environment variables. This can be (in addition to this workflow) used to spin up multiple services or repositories with a single command. The environment variable serves as an absolute path pointer to the root of whatever structure you have set up. Other repositories can then use relative paths after referencing the top level variable to get complete paths of the vault repository or other repositories in the directory structure. This 'env variable pointer' method ensures a consistent workflow which I developed for my personal projects and also integrated into multiple commercial projects.

### Node.js

Node.js commonly leverages the `package.json` file for launching scripts and sourcing environment variables. You can also use the `dotenv` package to load the `.env` files from the vault repository. If you know that you will be running your code on `UNIX` systems exclusively, you can use the following code in your `package.json` file:

```json
{
  "scripts": {
    "dev": ". \"$MY_PROJECT_VAULT_PATH/vault/some_service.env\" && . \"$MY_PROJECT_VAULT_PATH/local/some_service.env\" && nodemon --inspect=0.0.0.0:12345 src/index.js"
  }
}
```

Although the syntax is a bit longer than usual commands and may appear cumbersome, the advantages vastly outweigh the disadvantages in my experience. You set it up once and then it just works. The development speed increases without sacrificing security.

### Python

Python relies on the `python-dotenv` package to load the `.env` files. You can use the following code to load the environment files from the vault in your Python script:

```python
import os

from dotenv import load_dotenv

filepath_vault = os.path.join(*[os.getenv('MY_PROJECT_VAULT_PATH'), 'vault', 'some_service.env'])
filepath_local = os.path.join(*[os.getenv('MY_PROJECT_VAULT_PATH'), 'local', 'some_service.env'])

load_dotenv(filepath_vault)

if os.getenv('PYTHON_ENV') == 'development' and os.path.exists(filepath_local):
	load_dotenv(filepath_local, override=True)
```

This can also be abstracted into a utility library or a function which receives the name or relative path of the `.env` file and loads it into the environment and if the code is running inside a local environment, also loads the `.env` file from the `local/` directory to override specific variables.

Example:

```python
# utils.py

import os

from dotenv import load_dotenv


def load_env(filename: str):
	'''
	Loads the environment variables from the vault and local directories depending on the PYTHON_ENV environment variable.
	'''

	filepath_vault = os.path.join(*[os.getenv('MY_PROJECT_VAULT_PATH'), 'vault', filename])
	filepath_local = os.path.join(*[os.getenv('MY_PROJECT_VAULT_PATH'), 'local', filename])

	load_dotenv(filepath_vault)

	if os.getenv('PYTHON_ENV') == 'development' and os.path.exists(filepath_local):
		load_dotenv(filepath_local, override=True)
```

```python
# main.py

from utils import load_env

load_env('some_service.env')
```

### Docker

I strongly discourage listing environment files when using the `docker run` command as it still doesn't have consistent variable parsing. Instead, use a `docker-compose` file to load the `.env` files and overrides as Docker Compose actually works correctly in this regard. It has other benefits (even for local development) over `docker run` as well. You can use the following code in your `docker-compose.yml` file:

```yaml
version: "3.9"

services:
	some_service:
		env_file:
			- ${MY_PROJECT_VAULT_PATH}/vault/some_service.env
			- ${MY_PROJECT_VAULT_PATH}/local/some_service.env
		# you can still use the environment key to further override the values
		environment:
			SOME_SERVICE_ENV_VAR: some_value
#...
```

# TODO

- Create a workflow to set a config file with filepaths and their permissions (Windows wipes out permissions when copying files, add them back if necessary as a post-process)
- Create a template initialization script that sets up the repository with the necessary files and folders from scratch
- Use system credential manager to store the encryption key
- Maintenance scripts (clear git history, ...)
- Try to unify encryption and decryption code to only use shell scripts for cross-platform compatibility (Git bash on Windows)

# DONE

- Write up further instructions, use cases, and examples for multiple programming languages and workflows
- Update instructions for setting up a new instance from this template
- Check cross-platform collaboration compatibility
- Create Windows scripts (check if git bash works out of the box and openssl and tar are installed, use robocopy instead of rsync) -> Git bash relies on WSL... Created `decrypt.ps1` and `encrypt.ps1` scripts instead. Tar and openssl worked out of the box. Robocopy is used instead of rsync.
- Write README.md
- Adapt local code to the template
