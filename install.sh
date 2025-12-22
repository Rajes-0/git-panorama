#!/bin/bash
# GitStats - Install and setup (run once)
# Usage: ./install.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

echo "=========================================="
echo "GitStats - Installation & Setup"
echo "=========================================="
echo ""

# Check prerequisites
echo "Checking prerequisites..."

if ! command -v docker &> /dev/null; then
    echo "❌ Error: Docker is not installed"
    echo "Install: https://www.docker.com/products/docker-desktop"
    exit 1
fi

if ! command -v python3 &> /dev/null; then
    echo "❌ Error: Python 3 is not installed"
    exit 1
fi

if ! command -v uv &> /dev/null; then
    echo "Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.cargo/bin:$PATH"
fi

echo "✓ All prerequisites met"
echo ""

# Install Python dependencies
echo "Installing Python dependencies..."
if uv pip install -r requirements.txt --system 2>/dev/null; then
    echo "✓ Dependencies installed (system)"
elif uv pip install -r requirements.txt 2>/dev/null; then
    echo "✓ Dependencies installed (user)"
else
    echo "⚠ UV install failed, trying pip..."
    python3 -m pip install -r requirements.txt --user --break-system-packages
    echo "✓ Dependencies installed (pip user)"
fi
echo ""

# Start Docker services
echo "Starting Docker services..."
docker compose up -d
echo "✓ Docker services started"
echo ""

# Wait for Elasticsearch
echo "Waiting for Elasticsearch to be ready..."
until curl -s http://localhost:9200/_cluster/health > /dev/null 2>&1; do
    echo "  Still waiting..."
    sleep 5
done
echo "✓ Elasticsearch is ready"
echo ""

# Setup Elasticsearch indices
echo "Setting up Elasticsearch indices..."
./scripts/setup-elasticsearch-indices.sh
echo ""

echo "=========================================="
echo "✓ Installation Complete!"
echo "=========================================="
echo ""
echo "Services running:"
echo "  • Grafana:       http://localhost:3000 (admin/admin)"
echo "  • Elasticsearch: http://localhost:9200"
echo "  • Dejavu:        http://localhost:1358"
echo ""
echo "Next steps:"
echo "  1. Clone repositories into ./repositories/"
echo "  2. Configure email mapping in config.yaml"
echo "  3. Run: ./run.sh"
echo ""
echo "Note: You only need to run ./install.sh once."
echo "      Use ./run.sh for regular updates."
echo ""

