#!/bin/bash
# Clear Grafana and Elasticsearch caches to fix "no data" issues
# This script can be run without restarting the entire Docker stack

set -e

ES_HOST="${ES_HOST:-localhost}"
ES_PORT="${ES_PORT:-9200}"
ES_URL="http://${ES_HOST}:${ES_PORT}"

GRAFANA_HOST="${GRAFANA_HOST:-localhost}"
GRAFANA_PORT="${GRAFANA_PORT:-3000}"
GRAFANA_URL="http://${GRAFANA_HOST}:${GRAFANA_PORT}"
GRAFANA_USER="${GF_ADMIN_USER:-admin}"
GRAFANA_PASSWORD="${GF_ADMIN_PASSWORD:-admin}"

echo "🧹 Clearing caches to fix Grafana data issues..."
echo ""

# Clear Elasticsearch query cache
echo "1️⃣  Clearing Elasticsearch query cache..."
curl -X POST "${ES_URL}/git-commits/_cache/clear?query=true" \
  -H "Content-Type: application/json" 2>/dev/null || echo "  ⚠️  Failed to clear query cache"
echo ""

# Clear Elasticsearch request cache
echo "2️⃣  Clearing Elasticsearch request cache..."
curl -X POST "${ES_URL}/git-commits/_cache/clear?request=true" \
  -H "Content-Type: application/json" 2>/dev/null || echo "  ⚠️  Failed to clear request cache"
echo ""

# Clear all Elasticsearch field data cache
echo "3️⃣  Clearing Elasticsearch field data cache..."
curl -X POST "${ES_URL}/git-commits/_cache/clear?fielddata=true" \
  -H "Content-Type: application/json" 2>/dev/null || echo "  ⚠️  Failed to clear field data cache"
echo ""

# Force refresh the index
echo "4️⃣  Forcing Elasticsearch index refresh..."
curl -X POST "${ES_URL}/git-commits/_refresh" \
  -H "Content-Type: application/json" 2>/dev/null || echo "  ⚠️  Failed to refresh index"
echo ""

# Verify index health
echo "5️⃣  Checking index health..."
curl -X GET "${ES_URL}/_cat/indices/git-commits?v&h=index,health,status,docs.count" 2>/dev/null
echo ""

# Get document count in time range
echo "6️⃣  Verifying data availability..."
DOC_COUNT=$(curl -s -X GET "${ES_URL}/git-commits/_count" -H "Content-Type: application/json" | grep -o '"count":[0-9]*' | cut -d':' -f2)
echo "  Total documents in git-commits index: ${DOC_COUNT}"
echo ""

echo "✅ Cache clearing complete!"
echo ""
echo "📝 Next steps:"
echo "   1. Go to Grafana dashboard: ${GRAFANA_URL}"
echo "   2. Refresh your browser (Ctrl+F5 or Cmd+Shift+R)"
echo "   3. Try changing the date range again"
echo ""
echo "💡 If the issue persists, try:"
echo "   - Restart only Grafana: docker restart gitstats-grafana"
echo "   - Check Elasticsearch logs: docker logs gitstats-elasticsearch"
echo "   - Check Grafana logs: docker logs gitstats-grafana"

