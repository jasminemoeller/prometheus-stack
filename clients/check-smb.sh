#!/bin/bash
# SMB/CIFS share monitoring script for Prometheus node_exporter textfile collector

# Configuration
TEXTFILE_DIR="/var/lib/node_exporter/textfile_collector"
METRIC_FILE="${TEXTFILE_DIR}/smb.prom"
TEMP_FILE="${TEXTFILE_DIR}/smb.prom.$$"

# SMB shares to check
# Format: "label:host:sharename:username:password"
# Use empty username for guest/anonymous access
SHARES=(
  "nas_backup:192.168.1.10:backup:::"
  "nas_media:192.168.1.10:media:::"
  # With authentication:
  # "server_data:192.168.1.20:data:username:password"
)

# Timeout
TIMEOUT=5

# Create textfile directory if it doesn't exist
mkdir -p "${TEXTFILE_DIR}"

# Start writing metrics
cat > "${TEMP_FILE}" << 'EOF'
# HELP smb_share_available SMB/CIFS share availability (1=available, 0=unavailable)
# TYPE smb_share_available gauge
EOF

# Check each SMB share
for share_config in "${SHARES[@]}"; do
  IFS=':' read -r label host sharename username password <<< "$share_config"
  
  echo "Checking SMB share ${label} (${sharename} on ${host})..." >&2
  
  # Build smbclient command
  if [ -z "$username" ] || [ "$username" = "" ]; then
    # Guest/anonymous access
    cmd="smbclient -N -L \"$host\" -g"
  else
    # Authenticated access
    cmd="smbclient -L \"$host\" -U \"$username\"%\"$password\" -g"
  fi
  
  # Run smbclient with timeout
  start_time=$(date +%s.%N)
  if timeout ${TIMEOUT} bash -c "$cmd" 2>&1 | grep -q "Disk|${sharename}|"; then
    end_time=$(date +%s.%N)
    duration=$(echo "$end_time - $start_time" | bc)
    
    echo "✓ ${label}: SMB share available" >&2
    echo "smb_share_available{share=\"${label}\",host=\"${host}\",sharename=\"${sharename}\"} 1" >> "${TEMP_FILE}"
    echo "smb_share_response_time_seconds{share=\"${label}\",host=\"${host}\",sharename=\"${sharename}\"} ${duration}" >> "${TEMP_FILE}"
  else
    echo "✗ ${label}: SMB share unavailable" >&2
    echo "smb_share_available{share=\"${label}\",host=\"${host}\",sharename=\"${sharename}\"} 0" >> "${TEMP_FILE}"
  fi
done

# Atomically replace the metrics file
mv "${TEMP_FILE}" "${METRIC_FILE}"

echo "SMB check complete. Metrics written to ${METRIC_FILE}" >&2