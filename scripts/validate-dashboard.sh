#!/bin/bash
# Validate Grafana Dashboard Configuration
# This script checks the dashboard JSON for common issues

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"
CONFIG_FILE="${CONFIG_FILE:-${PROJECT_DIR}/config.yaml}"
DASHBOARD_FILE="${PROJECT_DIR}/config/grafana/provisioning/dashboards/repository-overview.json"

# Read configuration from config.yaml (with fallback to environment variables)
if [ -f "${CONFIG_FILE}" ] && command -v python3 &> /dev/null; then
    ES_HOST="${ES_HOST:-$(python3 "${SCRIPT_DIR}/read-config.py" "${CONFIG_FILE}" "elasticsearch.host" 2>/dev/null || echo "localhost")}"
    ES_PORT="${ES_PORT:-$(python3 "${SCRIPT_DIR}/read-config.py" "${CONFIG_FILE}" "elasticsearch.port" 2>/dev/null || echo "9200")}"
else
    ES_HOST="${ES_HOST:-localhost}"
    ES_PORT="${ES_PORT:-9200}"
fi

ES_URL="${ES_URL:-http://${ES_HOST}:${ES_PORT}}"
GRAFANA_URL="${GRAFANA_URL:-http://localhost:3000}"

echo "🔍 Validating Grafana Dashboard Configuration"
echo "=============================================="
echo ""

# Check if dashboard file exists
if [ ! -f "$DASHBOARD_FILE" ]; then
    echo "❌ Dashboard file not found: $DASHBOARD_FILE"
    exit 1
fi
echo "✅ Dashboard file exists"

# Validate JSON syntax
if python3 -m json.tool "$DASHBOARD_FILE" > /dev/null 2>&1; then
    echo "✅ JSON syntax is valid"
else
    echo "❌ JSON syntax is invalid"
    exit 1
fi

# Check schema version
SCHEMA_VERSION=$(python3 -c "import json; print(json.load(open('$DASHBOARD_FILE'))['schemaVersion'])")
echo "✅ Schema version: $SCHEMA_VERSION"
if [ "$SCHEMA_VERSION" -lt 27 ]; then
    echo "⚠️  Warning: Schema version is quite old (< 27)"
fi

# Count panels
PANEL_COUNT=$(python3 -c "import json; print(len(json.load(open('$DASHBOARD_FILE'))['panels']))")
echo "✅ Panel count: $PANEL_COUNT"

# Check for hardcoded max values in fieldConfig
HARDCODED_MAX=$(grep -c '"max": [0-9]' "$DASHBOARD_FILE" || true)
if [ "$HARDCODED_MAX" -gt 0 ]; then
    echo "⚠️  Warning: Found $HARDCODED_MAX hardcoded max values (may clip data)"
else
    echo "✅ No hardcoded max values (auto-scaling enabled)"
fi

# Check for panel descriptions
PANELS_WITH_DESC=$(grep -c '"description":' "$DASHBOARD_FILE" || true)
echo "✅ Panels with descriptions: $PANELS_WITH_DESC / $PANEL_COUNT"
if [ "$PANELS_WITH_DESC" -lt "$PANEL_COUNT" ]; then
    echo "⚠️  Warning: Some panels missing descriptions"
fi

# Check time range
TIME_FROM=$(python3 -c "import json; print(json.load(open('$DASHBOARD_FILE'))['time']['from'])")
TIME_TO=$(python3 -c "import json; print(json.load(open('$DASHBOARD_FILE'))['time']['to'])")
echo "✅ Default time range: $TIME_FROM to $TIME_TO"

# Check refresh interval
REFRESH=$(python3 -c "import json; print(json.load(open('$DASHBOARD_FILE'))['refresh'])")
if [ -z "$REFRESH" ] || [ "$REFRESH" = "null" ]; then
    echo "⚠️  Warning: Auto-refresh is disabled"
else
    echo "✅ Auto-refresh: $REFRESH"
fi

# Check Elasticsearch connectivity
echo ""
echo "🔌 Checking Elasticsearch connectivity..."
if curl -s "$ES_URL/_cluster/health" > /dev/null 2>&1; then
    echo "✅ Elasticsearch is reachable at $ES_URL"
    
    # Check if git-commits index exists
    if curl -s "$ES_URL/git-commits" > /dev/null 2>&1; then
        echo "✅ git-commits index exists"
        
        # Get document count
        DOC_COUNT=$(curl -s "$ES_URL/git-commits/_count" | python3 -c "import sys, json; print(json.load(sys.stdin)['count'])")
        echo "✅ Document count: $DOC_COUNT commits"
        
        if [ "$DOC_COUNT" -eq 0 ]; then
            echo "⚠️  Warning: No documents in git-commits index"
        fi
    else
        echo "⚠️  Warning: git-commits index does not exist"
    fi
else
    echo "⚠️  Warning: Cannot connect to Elasticsearch at $ES_URL"
fi

# Check Grafana connectivity
echo ""
echo "🔌 Checking Grafana connectivity..."
if curl -s "$GRAFANA_URL/api/health" > /dev/null 2>&1; then
    echo "✅ Grafana is reachable at $GRAFANA_URL"
else
    echo "⚠️  Warning: Cannot connect to Grafana at $GRAFANA_URL"
fi

# Check for common field names used in queries
echo ""
echo "🔍 Validating field names in queries..."
REQUIRED_FIELDS=(
    "repository"
    "commit_id"
    "author_name"
    "commit_timestamp"
    "included_insertions"
    "included_deletions"
    "included_lines_changed"
)

for field in "${REQUIRED_FIELDS[@]}"; do
    if grep -q "\"$field\"" "$DASHBOARD_FILE"; then
        echo "✅ Field '$field' is used in queries"
    else
        echo "⚠️  Warning: Field '$field' not found in dashboard"
    fi
done

# Check aggregation sizes
echo ""
echo "📊 Checking aggregation sizes..."
python3 << 'EOF'
import json
import re

with open('config/grafana/provisioning/dashboards/repository-overview.json') as f:
    dashboard = json.load(f)

for panel in dashboard['panels']:
    panel_id = panel.get('id')
    panel_title = panel.get('title', 'Unknown')
    
    for target in panel.get('targets', []):
        for bucket in target.get('bucketAggs', []):
            if bucket.get('type') == 'terms':
                size = bucket.get('settings', {}).get('size', 'auto')
                field = bucket.get('field', 'unknown')
                print(f"✅ Panel {panel_id} ({panel_title}): {field} aggregation size = {size}")
EOF

echo ""
echo "=============================================="
echo "✅ Dashboard validation complete!"
echo ""
echo "Next steps:"
echo "1. Restart Grafana: docker restart gitstats-grafana"
echo "2. Open dashboard: $GRAFANA_URL/d/git-stats-repository"
echo "3. Verify all panels display data"
echo ""

