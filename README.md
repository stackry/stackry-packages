# Stackry Packages

Public signed APT repository for the Stackry station appliance CLI.

This repository is intentionally narrow. It hosts the installer script, public
signing key, APT metadata, and released `stackry-cli` Debian packages. Product
source code, station configuration, warehouse topology, credentials, and
support notes live in private Stackry systems.

## Install The CLI

Current public endpoint:

```bash
curl -fsSL https://stackry.github.io/stackry-packages/install.sh | sudo bash
sudo apt-get update
sudo apt-get install -y stackry-cli
stackry version
```

Future DNS endpoint, once configured:

```bash
curl -fsSL https://packages.stackry.com/install.sh | sudo bash
sudo apt-get update
sudo apt-get install -y stackry-cli
stackry version
```

The installer only configures the Stackry package source. It does not enroll a
station, install application services, or ask for business configuration.

## Station Setup

After the CLI is installed, authorized Stackry installers use the local station
commands on the appliance:

```bash
sudo stackry station configure
sudo stackry station vision install
sudo stackry station status
```

For an existing station, start with non-destructive checks:

```bash
sudo apt-get update
sudo apt-get install --only-upgrade -y stackry-cli
sudo stackry station status
sudo stackry station doctor
```

Detailed station runbooks are private. Do not paste station IDs, auth keys,
support bundles, or logs into this public repository.

## What Is Public

```text
install.sh
apt/
  dists/
  pool/
  stackry-packages.gpg
```

The generated APT metadata and `.deb` files are committed so appliances can
install from GitHub Pages. Do not edit generated package indexes by hand.

## Security Model

- Packages published here must contain no secrets.
- Stations trust signed APT metadata and package signatures, not GitHub login.
- Stations should not need a GitHub account, personal access token, or source
  repository clone to install the CLI.
- `install.sh` writes the public signing key to
  `/usr/share/keyrings/stackry-packages.gpg`.
- The APT source uses `signed-by=/usr/share/keyrings/stackry-packages.gpg`.
- Tailscale auth keys, station tokens, and warehouse configuration are handled
  outside this public repository.

## Maintainers

`scripts/publish-apt-repo.sh` publishes `stackry-cli_*.deb` files into the
local APT tree, regenerates package indexes, exports the public signing key,
and signs Release metadata.

Publishing is normally done by GitHub Actions after a private Stackry source
workflow produces package artifacts. Required automation credentials are kept
as repository secrets and should grant only signing and read-artifact access
needed for publishing.

The package publisher runs in this public repository, so its default
`GITHUB_TOKEN` cannot read private `stackry/stackry-vision` workflow artifacts.
Configure a GitHub App for publishing before running
`.github/workflows/publish-stackry-cli.yaml`:

- GitHub App repository permission: `Actions: Read-only`
- GitHub App installation repository: `stackry/stackry-vision`
- `stackry/stackry-packages` repository variable:
  `STACKRY_PACKAGES_PUBLISHER_APP_ID`
- `stackry/stackry-packages` repository secret:
  `STACKRY_PACKAGES_PUBLISHER_APP_PRIVATE_KEY`

The workflow uses the GitHub App private key only inside GitHub Actions to
create a short-lived artifact-read token. Do not put this key or token on
station appliances.

Validate local changes before opening a pull request:

```bash
bash -n install.sh scripts/publish-apt-repo.sh tests/test_publish_apt_repo.sh
tests/test_publish_apt_repo.sh
```
