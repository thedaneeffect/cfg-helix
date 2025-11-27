#!/usr/bin/env bash
# Spin up Ubuntu container for testing dotfiles setup

docker run -it --rm \
  -v "$PWD:/dotfiles" \
  --name dotfiles-test \
  ubuntu:latest \
  bash -c '
    apt-get update -qq && apt-get install -y -qq curl git sudo build-essential procps file

    # Create non-root user (Homebrew requirement)
    useradd -m -s /bin/bash -G sudo testuser
    echo "testuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

    # Pre-create Homebrew directory with proper permissions
    mkdir -p /home/linuxbrew/.linuxbrew
    chown -R testuser:testuser /home/linuxbrew

    echo ""
    echo "=== Dotfiles Test Environment ==="
    echo "User: testuser (with sudo)"
    echo "Directory: /dotfiles"
    echo "Homebrew path: /home/linuxbrew/.linuxbrew"
    echo ""
    echo "Run: ./setup.sh"
    echo ""

    # Switch to testuser in /dotfiles directory
    exec su - testuser -c "cd /dotfiles && exec bash"
  '
