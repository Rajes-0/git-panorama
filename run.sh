#!/bin/bash
# GitStats - Clone/update repositories, analyze, and update dashboards
# Usage: ./run.sh
# Safe to run multiple times - clones new repos, updates existing ones, and refreshes data

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

CONFIG_FILE="${CONFIG_FILE:-${SCRIPT_DIR}/config.yaml}"
ES_HOST="${ES_HOST:-localhost}"
ES_PORT="${ES_PORT:-9200}"
ES_URL="http://${ES_HOST}:${ES_PORT}"

echo "=========================================="
echo "GitStats - Run Analysis"
echo "=========================================="
echo "Config: ${CONFIG_FILE}"
echo "Elasticsearch: ${ES_URL}"
echo ""

# Check prerequisites
if [ ! -f "${CONFIG_FILE}" ]; then
    echo "❌ Error: Configuration file not found: ${CONFIG_FILE}"
    exit 1
fi

if ! python3 -c "import yaml" 2>/dev/null; then
    echo "❌ Error: PyYAML not installed. Run: uv pip install -r requirements.txt --system"
    exit 1
fi

if ! curl -s "${ES_URL}/_cluster/health" > /dev/null; then
    echo "❌ Error: Cannot connect to Elasticsearch at ${ES_URL}"
    echo "Run: ./install.sh first to start services"
    exit 1
fi

echo "✓ Prerequisites met"
echo ""

# Clone/update repositories first
echo "Cloning/updating repositories..."
"${SCRIPT_DIR}/scripts/clone-repositories.sh" || {
    echo ""
    echo "⚠ Warning: Some repositories failed to clone/update, but continuing with analysis..."
}

echo ""

# Run analysis
echo "Analyzing repositories..."
python3 "${SCRIPT_DIR}/scripts/analyze_git_commits.py" "${CONFIG_FILE}"
EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ]; then
    echo ""
    echo "⚠ Error: Analysis failed with exit code $EXIT_CODE"
    exit 1
fi

echo ""
echo "✓ Analysis complete"
echo ""

# Upload to Elasticsearch
echo "Uploading to Elasticsearch..."
"${SCRIPT_DIR}/scripts/upload-to-elasticsearch.sh"
echo ""

# Check for unmapped emails
echo "Checking for unmapped emails..."
python3 "${SCRIPT_DIR}/scripts/find_unmapped_emails.py" "${CONFIG_FILE}"
echo ""

# Show statistics
echo "=========================================="
echo "Statistics"
echo "=========================================="
curl -s "${ES_URL}/_cat/indices/git-*?v&h=index,docs.count,store.size"
echo ""

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
echo "✓ Analysis Complete!"
echo "=========================================="
echo ""
echo "View dashboards: http://localhost:3000"
echo ""
echo "Run ./run.sh again anytime to update with latest changes."
echo ""

