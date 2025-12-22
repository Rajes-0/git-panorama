#!/bin/bash
# Upload all git statistics data to Elasticsearch
# This script uploads commits, tags, and LOC data with batching support

set -e

ES_HOST="${ES_HOST:-localhost}"
ES_PORT="${ES_PORT:-9200}"
ES_URL="http://${ES_HOST}:${ES_PORT}"
DATA_DIR="${DATA_DIR:-./git-stats}"
BATCH_SIZE="${BATCH_SIZE:-3000}"  # Number of documents per batch (reduced for memory constraints)
MAX_RETRIES=3  # Maximum number of retries for failed batches
BATCH_DELAY="${BATCH_DELAY:-1}"  # Delay in seconds between batches to allow ES to process

echo "=========================================="
echo "Git Stats Elasticsearch Upload"
echo "=========================================="
echo "Elasticsearch: ${ES_URL}"
echo "Data directory: ${DATA_DIR}"
echo "Batch size: ${BATCH_SIZE} documents"
echo ""

# Check if data directory exists
if [ ! -d "${DATA_DIR}" ]; then
    echo "Error: Data directory not found: ${DATA_DIR}"
    exit 1
fi

# Function to upload bulk data with batching
upload_bulk() {
    local file=$1
    local description=$2
    
    if [ ! -f "${file}" ]; then
        echo "⚠️  Warning: ${description} file not found: ${file}"
        return 0
    fi
    
    echo "Uploading ${description}..."
    
    # Count documents in file (each document is 2 lines: action + document)
    local doc_count=$(grep -c "^{\"index\"" "${file}" || echo "0")
    
    if [ "${doc_count}" -eq "0" ]; then
        echo "  No documents to upload"
        return 0
    fi
    
    echo "  Total documents: ${doc_count}"
    
    # Calculate number of batches needed
    local num_batches=$(( (doc_count + BATCH_SIZE - 1) / BATCH_SIZE ))
    echo "  Splitting into ${num_batches} batch(es) of up to ${BATCH_SIZE} documents"
    
    # Create temporary directory for batches
    local temp_dir=$(mktemp -d)
    
    # Split file into batches (each document is 2 lines)
    local lines_per_batch=$((BATCH_SIZE * 2))
    split -l ${lines_per_batch} "${file}" "${temp_dir}/batch_"
    
    # Upload each batch
    local batch_num=0
    local total_uploaded=0
    local failed_batches=0
    
    for batch_file in "${temp_dir}"/batch_*; do
        batch_num=$((batch_num + 1))
        local batch_doc_count=$(grep -c "^{\"index\"" "${batch_file}" || echo "0")
        
        echo "  Batch ${batch_num}/${num_batches}: uploading ${batch_doc_count} documents..."
        
        # Retry logic with exponential backoff
        local retry_count=0
        local success=false
        
        while [ ${retry_count} -lt ${MAX_RETRIES} ] && [ "${success}" = "false" ]; do
            if [ ${retry_count} -gt 0 ]; then
                local wait_time=$((2 ** retry_count * 5))
                echo "    Retry ${retry_count}/${MAX_RETRIES} after ${wait_time}s..."
                sleep ${wait_time}
            fi
            
            # Upload to Elasticsearch
            response=$(curl -s -w "\n%{http_code}" -X POST "${ES_URL}/_bulk" \
                -H "Content-Type: application/x-ndjson" \
                --data-binary "@${batch_file}")
            
            http_code=$(echo "${response}" | tail -n1)
            body=$(echo "${response}" | sed '$d')
            
            if [ "${http_code}" -eq "200" ]; then
                # Parse response to check for errors
                errors=$(echo "${body}" | grep -o '"errors":[^,]*' | cut -d':' -f2 || echo "true")
                
                if [ "${errors}" = "false" ]; then
                    echo "    ✓ Successfully uploaded ${batch_doc_count} documents"
                    total_uploaded=$((total_uploaded + batch_doc_count))
                    success=true
                else
                    echo "    ⚠️  Upload completed with some errors"
                    failed_batches=$((failed_batches + 1))
                    # Show first error for debugging
                    echo "${body}" | python3 -c "import sys, json; data=json.load(sys.stdin); items=[i for i in data.get('items',[]) if 'error' in i.get('index',{})]; print('    First error:', items[0]['index']['error'] if items else 'Unknown')" 2>/dev/null || true
                    success=true  # Don't retry on document-level errors
                fi
            elif [ "${http_code}" -eq "429" ]; then
                echo "    ✗ Rate limited (HTTP 429)"
                retry_count=$((retry_count + 1))
            else
                echo "    ✗ Upload failed (HTTP ${http_code})"
                echo "${body}" | python3 -m json.tool 2>/dev/null | head -20 || echo "${body}"
                retry_count=$((retry_count + 1))
            fi
        done
        
        if [ "${success}" = "false" ]; then
            echo "    ✗ Failed after ${MAX_RETRIES} retries"
            failed_batches=$((failed_batches + 1))
        fi
        
        # Add delay between batches to allow Elasticsearch to process and free memory
        if [ ${batch_num} -lt ${num_batches} ]; then
            sleep ${BATCH_DELAY}
        fi
    done
    
    # Clean up temporary directory
    rm -rf "${temp_dir}"
    
    echo "  Summary: ${total_uploaded}/${doc_count} documents uploaded successfully"
    if [ ${failed_batches} -gt 0 ]; then
        echo "  ⚠️  ${failed_batches} batch(es) had errors"
    fi
    echo ""
    
    return 0
}

# Upload commits data
echo "Uploading Git Commits"
echo "---------------------"
upload_bulk "${DATA_DIR}/commits-bulk.json" "commits data"

# Verify upload
echo "=========================================="
echo "Verification"
echo "=========================================="
echo ""

echo "Document count:"
curl -s "${ES_URL}/_cat/indices/git-commits?v&h=index,docs.count"

echo ""
echo "✓ Upload complete!"
