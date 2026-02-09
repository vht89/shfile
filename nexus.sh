#!/bin/bash

# Nexus Network Auto Setup & Run Script
# Node ID: 37687190

set -e

echo "================================================"
echo "🚀 Nexus Network Auto Setup Script"
echo "================================================"

# Update system
echo "📦 Updating system packages..."
apt-get update -qq

# Install dependencies
echo "📥 Installing dependencies..."
apt-get install -y curl git build-essential pkg-config libssl-dev

# Install Rust
echo "🦀 Installing Rust..."
if ! command -v rustc &> /dev/null; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source $HOME/.cargo/env
    export PATH="$HOME/.cargo/bin:$PATH"
    echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> ~/.bashrc
else
    echo "✅ Rust already installed"
fi

# Verify Rust installation
rustc --version
cargo --version

# Install Nexus CLI
echo "⚙️ Installing Nexus CLI..."
if ! command -v nexus &> /dev/null; then
    curl https://cli.nexus.xyz/ | sh
    export PATH="$HOME/.nexus/bin:$PATH"
    echo 'export PATH="$HOME/.nexus/bin:$PATH"' >> ~/.bashrc
else
    echo "✅ Nexus CLI already installed"
fi

# Create Nexus directory
mkdir -p $HOME/.nexus

# Setup prover ID
echo "🔑 Setting up Prover ID..."
echo "37687190" > $HOME/.nexus/prover-id

echo "================================================"
echo "✅ Installation completed!"
echo "================================================"
echo "Node ID: 37687190"
echo "Starting Nexus Prover..."
echo "================================================"

# Start proving
cd $HOME
nexus prove
