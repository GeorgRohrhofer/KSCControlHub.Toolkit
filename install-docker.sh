#!/usr/bin/env bash
#
# install-docker.sh — Install Docker Engine + Compose plugin on Debian
# Follows the official Docker apt repository method.
# Usage:  sudo ./install-docker.sh
#

set -euo pipefail

# ---- 0. Sanity checks --------------------------------------------------------
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root (try: sudo $0)" >&2
    exit 1
fi

if ! grep -qi 'debian' /etc/os-release; then
    echo "Warning: this script targets Debian. Detected:" >&2
    grep PRETTY_NAME /etc/os-release >&2
    read -rp "Continue anyway? [y/N] " ans
    [[ "${ans,,}" == "y" ]] || exit 1
fi

# The user to add to the 'docker' group (so they can run docker without sudo).
# Falls back to the invoking sudo user, or skip if running as raw root.
TARGET_USER="${SUDO_USER:-}"

# ---- 1. Remove old/conflicting packages --------------------------------------
echo ">>> Removing any conflicting packages..."
for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do
    apt-get remove -y "$pkg" 2>/dev/null || true
done

# ---- 2. Install prerequisites ------------------------------------------------
echo ">>> Installing prerequisites..."
apt-get update
apt-get install -y ca-certificates curl gnupg

# ---- 3. Add Docker's official GPG key ----------------------------------------
echo ">>> Adding Docker GPG key..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg \
    -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

# ---- 4. Add the Docker apt repository ----------------------------------------
echo ">>> Adding Docker apt repository..."
ARCH="$(dpkg --print-architecture)"
CODENAME="$(. /etc/os-release && echo "${VERSION_CODENAME:-$DEBIAN_CODENAME}")"

echo \
  "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.asc] \
  https://download.docker.com/linux/debian ${CODENAME} stable" \
  > /etc/apt/sources.list.d/docker.list

# ---- 5. Install Docker Engine + plugins --------------------------------------
echo ">>> Installing Docker Engine, CLI, containerd, Buildx, Compose..."
apt-get update
apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

# ---- 6. Enable & start the service -------------------------------------------
echo ">>> Enabling and starting docker.service..."
systemctl enable --now docker

# ---- 7. Allow non-root user to run docker ------------------------------------
if [[ -n "$TARGET_USER" ]] && id "$TARGET_USER" &>/dev/null; then
    echo ">>> Adding user '$TARGET_USER' to the 'docker' group..."
    usermod -aG docker "$TARGET_USER"
    echo "    (Log out and back in, or run 'newgrp docker', for it to take effect.)"
else
    echo ">>> Skipping docker-group setup (no non-root user detected)."
fi

# ---- 8. Verify ---------------------------------------------------------------
echo ">>> Verifying installation..."
docker --version
docker compose version

echo
echo "Docker installed successfully."
echo "Quick test:  docker run --rm hello-world"
