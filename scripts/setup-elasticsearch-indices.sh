#!/bin/bash
# Setup Elasticsearch indices for git statistics
# This script creates all necessary indices with proper mappings

set -e

ES_HOST="${ES_HOST:-localhost}"
ES_PORT="${ES_PORT:-9200}"
ES_URL="http://${ES_HOST}:${ES_PORT}"

echo "Setting up Elasticsearch indices at ${ES_URL}"
echo ""

# ============================================================================
# Git Commits Index
# ============================================================================
echo "Creating git-commits index..."

curl -X DELETE "${ES_URL}/git-commits" 2>/dev/null || true
echo ""

curl -X PUT "${ES_URL}/git-commits" -H "Content-Type: application/json" -d '{
  "settings": {
    "number_of_shards": 1,
    "number_of_replicas": 0
  },
  "mappings": {
    "properties": {
      "repository": { 
        "type": "keyword" 
      },
      "commit_id": { 
        "type": "keyword" 
      },
      "author_email": { 
        "type": "keyword" 
      },
      "author_name": { 
        "type": "keyword" 
      },
      "commit_timestamp": { 
        "type": "date" 
      },
      "files_changed": { 
        "type": "integer" 
      },
      "insertions": { 
        "type": "integer" 
      },
      "deletions": { 
        "type": "integer" 
      },
      "lines_changed": { 
        "type": "integer" 
      }
    }
  }
}'

echo ""
echo "✓ git-commits index created"
echo ""

# ============================================================================
# Git Tags Index
# ============================================================================
echo "Creating git-tags index..."

curl -X DELETE "${ES_URL}/git-tags" 2>/dev/null || true
echo ""

curl -X PUT "${ES_URL}/git-tags" -H "Content-Type: application/json" -d '{
  "settings": {
    "number_of_shards": 1,
    "number_of_replicas": 0
  },
  "mappings": {
    "properties": {
      "repository": { 
        "type": "keyword" 
      },
      "tag_name": { 
        "type": "keyword" 
      },
      "commit_hash": { 
        "type": "keyword" 
      },
      "commit_timestamp": { 
        "type": "date" 
      },
      "tag_timestamp": { 
        "type": "date" 
      },
      "author_email": { 
        "type": "keyword" 
      },
      "author_name": { 
        "type": "keyword" 
      },
      "semver_major": { 
        "type": "integer" 
      },
      "semver_minor": { 
        "type": "integer" 
      },
      "semver_patch": { 
        "type": "integer" 
      },
      "semver_prerelease": { 
        "type": "keyword" 
      },
      "semver_build": { 
        "type": "keyword" 
      },
      "is_prerelease": { 
        "type": "boolean" 
      }
    }
  }
}'

echo ""
echo "✓ git-tags index created"
echo ""

# ============================================================================
# Git LOC Index
# ============================================================================
echo "Creating git-loc index..."

curl -X DELETE "${ES_URL}/git-loc" 2>/dev/null || true
echo ""

curl -X PUT "${ES_URL}/git-loc" -H "Content-Type: application/json" -d '{
  "settings": {
    "number_of_shards": 1,
    "number_of_replicas": 0
  },
  "mappings": {
    "properties": {
      "repository": { 
        "type": "keyword" 
      },
      "timestamp": { 
        "type": "date" 
      },
      "total_lines": { 
        "type": "integer" 
      },
      "total_files": { 
        "type": "integer" 
      },
      "contributor_count": { 
        "type": "integer" 
      },
      "contributors": { 
        "type": "keyword" 
      },
      "languages": { 
        "type": "object",
        "enabled": true
      },
      "date_range_start": { 
        "type": "keyword" 
      },
      "date_range_end": { 
        "type": "keyword" 
      }
    }
  }
}'

echo ""
echo "✓ git-loc index created"
echo ""

# ============================================================================
# Verify indices
# ============================================================================
echo "Verifying indices..."
echo ""

curl -X GET "${ES_URL}/_cat/indices/git-*?v" 

echo ""
echo "✓ All indices created successfully!"

