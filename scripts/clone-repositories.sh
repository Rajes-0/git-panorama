#!/bin/bash
# Clone or update all repositories from config.yaml
# Fetches all branches and tags for each repository

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"
CONFIG_FILE="${CONFIG_FILE:-${PROJECT_DIR}/config.yaml}"

echo "=========================================="
echo "Git Repository Cloner"
echo "=========================================="
echo "Project directory: ${PROJECT_DIR}"
echo "Config file: ${CONFIG_FILE}"
echo ""

# Check if config file exists
if [ ! -f "${CONFIG_FILE}" ]; then
    echo "❌ Error: Config file not found: ${CONFIG_FILE}"
    exit 1
fi

# Check if Python is available
if ! command -v python3 &> /dev/null; then
    echo "❌ Error: python3 is required but not installed"
    exit 1
fi

# Check if PyYAML is installed
if ! python3 -c "import yaml" 2>/dev/null; then
    echo "❌ Error: PyYAML is required. Install with: pip install pyyaml"
    exit 1
fi

# Extract repository URLs from config.yaml using Python
REPO_URLS=$(python3 -c "
import yaml
import sys

try:
    with open('${CONFIG_FILE}', 'r') as f:
        config = yaml.safe_load(f)
    
    repo_urls = config.get('repositories', {}).get('repository_urls', [])
    
    if not repo_urls:
        sys.exit(0)
    
    for url in repo_urls:
        print(url)
        
except Exception as e:
    print(f'Error reading config: {e}', file=sys.stderr)
    sys.exit(1)
")

# Check if we got any URLs
if [ -z "$REPO_URLS" ]; then
    echo "⚠️  No repository URLs found in config.yaml"
    echo ""
    echo "Please add repository URLs to the 'repositories.repository_urls' section in config.yaml"
    exit 0
fi

# Get base directory from config
BASE_DIR=$(python3 -c "
import yaml

with open('${CONFIG_FILE}', 'r') as f:
    config = yaml.safe_load(f)

base_dir = config.get('repositories', {}).get('base_directory', './repositories')
print(base_dir)
")

# Create repositories directory if it doesn't exist
mkdir -p "${PROJECT_DIR}/${BASE_DIR}"

echo "Base directory: ${BASE_DIR}"
echo ""

# Count total repositories
TOTAL_REPOS=$(echo "$REPO_URLS" | wc -l | tr -d ' ')
CURRENT=0
SUCCESS=0
FAILED=0

echo "Found ${TOTAL_REPOS} repositories to clone/update"
echo ""

# Function to draw progress bar
draw_progress_bar() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local completed=$((width * current / total))
    local remaining=$((width - completed))
    
    printf "\rProgress: ["
    printf "%${completed}s" | tr ' ' '█'
    printf "%${remaining}s" | tr ' ' '░'
    printf "] %3d%% (%d/%d)" "$percentage" "$current" "$total"
}

# Clone or update each repository
while IFS= read -r repo_url; do
    # Skip empty lines
    [ -z "$repo_url" ] && continue
    
    CURRENT=$((CURRENT + 1))
    
    # Extract repository name from URL
    # Handles both git@github.com:user/repo.git and https://github.com/user/repo.git
    repo_name=$(basename "$repo_url" .git)
    
    # Draw progress bar
    draw_progress_bar $CURRENT $TOTAL_REPOS
    echo ""
    echo ""
    echo "[$CURRENT/$TOTAL_REPOS] Processing: $repo_name"
    echo "  URL: $repo_url"
    
    repo_path="${PROJECT_DIR}/${BASE_DIR}/${repo_name}"
    
    if [ -d "$repo_path/.git" ]; then
        echo "  ✓ Repository exists, fetching all branches and tags..."
        
        # Get current HEAD before fetch
        OLD_HEAD=$(cd "$repo_path" && git rev-parse HEAD 2>/dev/null || echo "")
        
        if (cd "$repo_path" && \
            git fetch --all --tags --prune && \
            git remote update origin --prune && \
            git branch -r | grep -v '\->' | while read remote; do 
                branch="${remote#origin/}"
                git branch --track "$branch" "$remote" 2>/dev/null || true
            done); then
            
            # Get new HEAD after fetch
            NEW_HEAD=$(cd "$repo_path" && git rev-parse HEAD 2>/dev/null || echo "")
            
            # Check if there are new commits in any branch
            NEW_COMMITS=$(cd "$repo_path" && git log --all --oneline --since="1 minute ago" 2>/dev/null | wc -l | tr -d ' ')
            
            if [ "$OLD_HEAD" != "$NEW_HEAD" ] || [ "$NEW_COMMITS" -gt 0 ]; then
                echo "  ✓ Fetched successfully - Changes detected!"
            else
                echo "  ✓ Fetched successfully - No new changes"
            fi
            SUCCESS=$((SUCCESS + 1))
        else
            echo "  ⚠️  Fetch failed"
            FAILED=$((FAILED + 1))
        fi
    else
        echo "  → Cloning..."
        
        if git clone "$repo_url" "$repo_path"; then
            echo "  → Fetching all branches and tags..."
            
            if (cd "$repo_path" && \
                git fetch --all --tags --prune && \
                git branch -r | grep -v '\->' | while read remote; do 
                    branch="${remote#origin/}"
                    git branch --track "$branch" "$remote" 2>/dev/null || true
                done); then
                echo "  ✓ Cloned successfully"
                SUCCESS=$((SUCCESS + 1))
            else
                echo "  ⚠️  Cloned but failed to fetch all branches"
                SUCCESS=$((SUCCESS + 1))
            fi
        else
            echo "  ❌ Clone failed"
            FAILED=$((FAILED + 1))
        fi
    fi
    
    echo ""
done <<< "$REPO_URLS"

# Draw final progress bar
echo ""
draw_progress_bar $TOTAL_REPOS $TOTAL_REPOS
echo ""
echo ""

echo "=========================================="
echo "✓ Repository cloning complete!"
echo "=========================================="
echo "Total repositories: ${TOTAL_REPOS}"
echo "Successful: ${SUCCESS}"
echo "Failed: ${FAILED}"
echo ""
echo "Repositories are in: ${BASE_DIR}/"
echo ""
echo "Next steps:"
echo "  1. Edit config.yaml to configure email mapping and exclusions"
echo "  2. Run: ./scripts/update-all-stats.sh"
echo "  3. Open Grafana at http://localhost:3000 (admin/admin)"
echo ""

