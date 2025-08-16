#!/bin/bash
# Site Audit Script with Tuned Nikto, Detached Execution, and Color Coding

# ANSI color codes
RED="\033[1;31m"
YELLOW="\033[1;33m"
GREEN="\033[1;32m"
CYAN="\033[1;36m"
NC="\033[0m" # No Color

# Timestamped output folder
OUTDIR="audit_reports/$(date +'%Y%m%d_%H%M%S')"
mkdir -p "$OUTDIR"

# Domains to scan
DOMAINS=(
  "aidanwatters.kesug.com"
)

# Logging function
log() {
  echo -e "${CYAN}[INFO]${NC} $1"
}

# Check if a tool exists
have() {
  command -v "$1" >/dev/null 2>&1
}

# Run tuned Nikto scan (detached)
run_nikto() {
  local host="$1"
  if have nikto; then
    log "Running tuned Nikto scan on ${host} (detached)"
    nikto -host "https://${host}" -Tuning 1 2 3 -ask no -C all \
      > "${OUTDIR}/${host}_nikto.txt" 2>&1 &
    NIKTO_PIDS+=($!)
  else
    log "Nikto not installed; skipping for ${host}"
  fi
}

# Colorize text
colorize_line() {
  local line="$1"
  if [[ "$line" =~ (CRITICAL|HIGH|VULNERABLE|FAIL) ]]; then
    echo -e "${RED}${line}${NC}"
  elif [[ "$line" =~ (WARNING|MEDIUM) ]]; then
    echo -e "${YELLOW}${line}${NC}"
  elif [[ "$line" =~ (INFO|LOW|OK) ]]; then
    echo -e "${GREEN}${line}${NC}"
  else
    echo -e "${CYAN}${line}${NC}"
  fi
}

# Generate risk score
generate_risk_score() {
  local summary_file="$1"
  local high_count=$(grep -E "(CRITICAL|HIGH|VULNERABLE|FAIL)" "$summary_file" | wc -l)
  local medium_count=$(grep -E "(WARNING|MEDIUM)" "$summary_file" | wc -l)
  local low_count=$(grep -E "(INFO|LOW|OK)" "$summary_file" | wc -l)

  echo -e "\n===== Risk Assessment ====="
  echo -e "${RED}High: $high_count${NC}"
  echo -e "${YELLOW}Medium: $medium_count${NC}"
  echo -e "${GREEN}Low: $low_count${NC}"

  if (( high_count > 5 )); then
    echo -e "${RED}Overall Risk: CRITICAL${NC}"
  elif (( high_count > 0 )); then
    echo -e "${YELLOW}Overall Risk: ELEVATED${NC}"
  elif (( medium_count > 0 )); then
    echo -e "${YELLOW}Overall Risk: MODERATE${NC}"
  else
    echo -e "${GREEN}Overall Risk: LOW${NC}"
  fi
}

# Main
SUMMARY_FILE="${OUTDIR}/_summary.txt"
> "$SUMMARY_FILE"
NIKTO_PIDS=()

for domain in "${DOMAINS[@]}"; do
  log "Auditing $domain"
  echo "===== $domain =====" >> "$SUMMARY_FILE"

  # Start Nikto in the background (detached)
  run_nikto "$domain"

  # Example test results for demo
  echo "INFO: Basic scan completed" >> "$SUMMARY_FILE"
  echo "WARNING: Missing security header X-Frame-Options" >> "$SUMMARY_FILE"
  echo "HIGH: Outdated WordPress version detected" >> "$SUMMARY_FILE"
done

# Print summary immediately
while IFS= read -r line; do
  colorize_line "$line"
done < "$SUMMARY_FILE"

# Print risk score
generate_risk_score "$SUMMARY_FILE"

# Wait for Nikto scans to finish
if (( ${#NIKTO_PIDS[@]} > 0 )); then
  log "Waiting for Nikto scans to finish..."
  wait "${NIKTO_PIDS[@]}"
  log "Nikto scans complete."
  
  # Show Nikto results
  for domain in "${DOMAINS[@]}"; do
    echo -e "\n${CYAN}===== Nikto Report for $domain =====${NC}"
    while IFS= read -r line; do
      colorize_line "$line"
    done < "${OUTDIR}/${domain}_nikto.txt"
  done
fi
