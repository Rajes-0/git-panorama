#!/bin/bash
# Update All Git Statistics
# This script runs all analysis scripts and uploads data to Elasticsearch
# It's safe to run multiple times - it will update existing data instead of duplicating

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"
CONFIG_FILE="${CONFIG_FILE:-${PROJECT_DIR}/config.yaml}"

ES_HOST="${ES_HOST:-localhost}"
ES_PORT="${ES_PORT:-9200}"
ES_URL="http://${ES_HOST}:${ES_PORT}"

echo "=========================================="
echo "Git Statistics Update Script"
echo "=========================================="
echo "Project directory: ${PROJECT_DIR}"
echo "Config file: ${CONFIG_FILE}"
echo "Elasticsearch: ${ES_URL}"
echo ""

# Check if config file exists
if [ ! -f "${CONFIG_FILE}" ]; then
    echo "Error: Configuration file not found: ${CONFIG_FILE}"
    exit 1
fi

# Check if Python is available
if ! command -v python3 &> /dev/null; then
    echo "Error: python3 is required but not installed"
    exit 1
fi

# Check if PyYAML is installed
if ! python3 -c "import yaml" 2>/dev/null; then
    echo "Error: PyYAML is required. Install with: uv pip install -r requirements.txt --system"
    exit 1
fi

# Check if Elasticsearch is running
echo "Checking Elasticsearch connection..."
if ! curl -s "${ES_URL}/_cluster/health" > /dev/null; then
    echo "Error: Cannot connect to Elasticsearch at ${ES_URL}"
    echo "Please ensure Elasticsearch is running (try: docker-compose up -d elasticsearch)"
    exit 1
fi
echo "✓ Elasticsearch is running"
echo ""

# Step 1-3: Run all analyses in parallel
echo "=========================================="
echo "Step 1-3: Analyzing Repositories"
echo "=========================================="
echo "Running commits, tags, and LOC analysis in parallel..."
echo ""

# Run all three analyses in parallel using background jobs
python3 "${SCRIPT_DIR}/analyze_git_commits.py" "${CONFIG_FILE}" &
PID_COMMITS=$!

python3 "${SCRIPT_DIR}/analyze_git_tags.py" "${CONFIG_FILE}" &
PID_TAGS=$!

python3 "${SCRIPT_DIR}/analyze_git_loc.py" "${CONFIG_FILE}" &
PID_LOC=$!

# Wait for all background jobs to complete
wait $PID_COMMITS
EXIT_COMMITS=$?

wait $PID_TAGS
EXIT_TAGS=$?

wait $PID_LOC
EXIT_LOC=$?

# Check if any analysis failed
if [ $EXIT_COMMITS -ne 0 ] || [ $EXIT_TAGS -ne 0 ] || [ $EXIT_LOC -ne 0 ]; then
    echo ""
    echo "⚠ Warning: Some analyses failed"
    echo "  Commits: exit code $EXIT_COMMITS"
    echo "  Tags: exit code $EXIT_TAGS"
    echo "  LOC: exit code $EXIT_LOC"
    exit 1
fi

echo ""
echo "✓ All analyses completed successfully"
echo ""

# Step 4: Upload to Elasticsearch
echo "=========================================="
echo "Step 4: Uploading to Elasticsearch"
echo "=========================================="
"${SCRIPT_DIR}/upload-to-elasticsearch.sh"
echo ""

# Step 5: Check for unmapped email addresses
echo "=========================================="
echo "Step 5: Checking for Unmapped Emails"
echo "=========================================="
python3 "${SCRIPT_DIR}/find_unmapped_emails.py" "${CONFIG_FILE}"
echo ""

# Step 6: Verify data
echo "=========================================="
echo "Final Statistics"
echo "=========================================="
echo ""
echo "Document counts by index:"
curl -s "${ES_URL}/_cat/indices/git-*?v&h=index,docs.count,store.size"
echo ""

# Show some sample statistics
echo "Recent commits by repository:"
curl -s -X GET "${ES_URL}/git-commits/_search?size=0" -H "Content-Type: application/json" -d '{
  "aggs": {
    "by_repository": {
      "terms": {
        "field": "repository",
        "size": 20
      }
    }
  }
}' | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    buckets = data['aggregations']['by_repository']['buckets']
    for bucket in buckets:
        print(f\"  {bucket['key']}: {bucket['doc_count']:,} commits\")
except Exception as e:
    print(f'  Could not parse results: {e}')
" 2>/dev/null || echo "  (statistics not available)"

echo ""
echo "=========================================="
echo "✓ Update Complete!"
echo "=========================================="
echo ""
echo "Your Grafana dashboards should now reflect the current state."
echo "You can safely run this script again to update the statistics."
echo ""

