#!/bin/bash
# DHCP monitoring script for Prometheus node_exporter textfile collector

# Configuration
TEXTFILE_DIR="/var/lib/node_exporter/textfile_collector"
METRIC_FILE="${TEXTFILE_DIR}/dhcp.prom"
TEMP_FILE="${TEXTFILE_DIR}/dhcp.prom.$$"

# DHCP servers to check
# Format: "server_label:dhcp_server_ip:test_ip:test_mac"
SERVERS=(
  "primary:192.168.1.1:192.168.1.200:00:11:22:33:44:55"
  # Add more servers here:
  # "secondary:10.0.0.1:10.0.0.200:00:11:22:33:44:66"
)

# Timeout for dhcping
TIMEOUT=3

# Create textfile directory if it doesn't exist
mkdir -p "${TEXTFILE_DIR}"

# Start writing metrics
cat > "${TEMP_FILE}" << EOF
# HELP dhcp_up DHCP server status (1=up, 0=down)
# TYPE dhcp_up gauge
EOF

# Check each DHCP server
for server_config in "${SERVERS[@]}"; do
  IFS=':' read -r label server test_ip test_mac <<< "$server_config"
  
  echo "Checking DHCP server ${label} (${server})..." >&2
  
  # Run dhcping
  start_time=$(date +%s.%N)
  if dhcping -c "${test_ip}" -s "${server}" -h "${test_mac}" -r -t "${TIMEOUT}" >/dev/null 2>&1; then
    end_time=$(date +%s.%N)
    duration=$(echo "$end_time - $start_time" | bc)
    
    echo "✓ ${label}: DHCP OK" >&2
    echo "dhcp_up{server=\"${label}\",dhcp_server=\"${server}\",test_ip=\"${test_ip}\"} 1" >> "${TEMP_FILE}"
    echo "dhcp_response_time_seconds{server=\"${label}\",dhcp_server=\"${server}\",test_ip=\"${test_ip}\"} ${duration}" >> "${TEMP_FILE}"
  else
    echo "✗ ${label}: DHCP FAILED" >&2
    echo "dhcp_up{server=\"${label}\",dhcp_server=\"${server}\",test_ip=\"${test_ip}\"} 0" >> "${TEMP_FILE}"
  fi
done

# Atomically replace the metrics file
mv "${TEMP_FILE}" "${METRIC_FILE}"

echo "DHCP check complete. Metrics written to ${METRIC_FILE}" >&2