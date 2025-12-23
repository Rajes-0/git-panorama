#!/bin/bash
# Wipe and recreate git-commits index
# WARNING: This deletes all commit data!

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"
CONFIG_FILE="${CONFIG_FILE:-${PROJECT_DIR}/config.yaml}"

# Read configuration from config.yaml (with fallback to environment variables)
if [ -f "${CONFIG_FILE}" ] && command -v python3 &> /dev/null; then
    ES_HOST="${ES_HOST:-$(python3 "${SCRIPT_DIR}/read-config.py" "${CONFIG_FILE}" "elasticsearch.host" 2>/dev/null || echo "localhost")}"
    ES_PORT="${ES_PORT:-$(python3 "${SCRIPT_DIR}/read-config.py" "${CONFIG_FILE}" "elasticsearch.port" 2>/dev/null || echo "9200")}"
else
    ES_HOST="${ES_HOST:-localhost}"
    ES_PORT="${ES_PORT:-9200}"
fi

ES_URL="http://${ES_HOST}:${ES_PORT}"

echo "⚠️  WARNING: This will delete all data in git-commits index!"
echo "Elasticsearch: ${ES_URL}"
echo ""

curl -X DELETE "${ES_URL}/git-commits"

curl -X PUT "${ES_URL}/git-commits" -H "Content-Type: application/json" -d '{
  "mappings": {
    "properties": {
      "repository": { "type": "keyword" },
      "commit_id": { "type": "keyword" },
      "author_email": { "type": "keyword" },
      "author_name": { "type": "keyword" },
      "commit_timestamp": { "type": "date" },
      "files_changed": { "type": "integer" },
      "insertions": { "type": "integer" },
      "deletions": { "type": "integer" },
      "lines_changed": { "type": "integer" }
    }
  }
}'

echo ""
echo "✓ Index recreated successfully"
