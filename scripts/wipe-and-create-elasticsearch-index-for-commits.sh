#!/bin/bash

curl -X DELETE "http://localhost:9200/git-commits"

curl -X PUT "http://localhost:9200/git-commits" -H "Content-Type: application/json" -d '{
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
