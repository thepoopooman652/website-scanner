#!/bin/bash

# ========================
# Color Codes
# ========================
GREEN="\e[32m"
YELLOW="\e[33m"
RED="\e[31m"
CYAN="\e[36m"
RESET="\e[0m"

# ========================
# Usage Function
# ========================
usage() {
    echo -e "${YELLOW}Usage:${RESET} $0 -d <domain> [options]"
    echo "  -d,  --domain             Main/root domain to scan (required)"
    echo "  -sd, --subdomains         Comma-separated subdomains to scan"
    echo "  -sdscan,  --subdomain-scan     Passive subdomain scan via subfinder"
    echo "  -sdscanb, --subdomain-scan-b   Advanced passive scan via subfinder -all"
    echo "  -tn, --tuned-nikto        Enable tuned Nikto scan"
    echo "  -h,  --help               Show this help message"
    exit 1
}

# ========================
# Dependency Check
# ========================
check_install() {
    local cmd=$1
    local pkg=$2
    local install_cmd=$3
    if ! command -v "$cmd" &> /dev/null; then
        echo -e "${YELLOW}[WARN]${RESET} $pkg not found."
        read -p "Install $pkg? (y/n): " choice
        if [[ "$choice" == "y" ]]; then
            eval "$install_cmd"
        else
            echo -e "${RED}[ERROR]${RESET} $pkg is required. Exiting."
            exit 1
        fi
    fi
}

# ========================
# Install Checks
# ========================
check_install go "Go" "sudo apt update && sudo apt install -y golang"
check_install subfinder "subfinder" "go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest && sudo cp ~/go/bin/subfinder /usr/local/bin/"

check_install whatweb "WhatWeb" "sudo apt update && sudo apt install -y whatweb"
check_install nmap "Nmap" "sudo apt update && sudo apt install -y nmap"
check_install nikto "Nikto" "sudo apt update && sudo apt install -y nikto"

# ========================
# Parse Arguments
# ========================
DOMAIN=""
SUBDOMAIN_LIST=""
RUN_SD_SCAN=false
RUN_SD_SCANB=false
TUNED_NIKTO=false

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -d|--domain) DOMAIN="$2"; shift ;;
        -sd|--subdomains) SUBDOMAIN_LIST="$2"; shift ;;
        -sdscan|--subdomain-scan) RUN_SD_SCAN=true ;;
        -sdscanb|--subdomain-scan-b) RUN_SD_SCANB=true ;;
        -tn|--tuned-nikto) TUNED_NIKTO=true ;;
        -h|--help) usage ;;
        *) echo -e "${RED}[ERROR]${RESET} Unknown option: $1"; usage ;;
    esac
    shift
done

if [[ -z "$DOMAIN" ]]; then
    echo -e "${RED}[ERROR]${RESET} Main domain is required."
    usage
fi

mkdir -p reports

# ========================
# Subdomain Gathering
# ========================
ALL_DOMAINS=()
# Add the main domain to the list of domains to scan
if [[ -n "$DOMAIN" ]]; then
    ALL_DOMAINS+=("$DOMAIN")
fi

MANUAL_SUBS=()
if [[ -n "$SUBDOMAIN_LIST" ]]; then
    IFS=',' read -ra MANUAL_SUBS <<< "$SUBDOMAIN_LIST"
    ALL_DOMAINS+=("${MANUAL_SUBS[@]}")
fi

FOUND_SUBS=()
if $RUN_SD_SCAN; then
    echo -e "${CYAN}[INFO]${RESET} Running passive subdomain scan..."
    mapfile -t FOUND_SUBS < <(subfinder -silent -d "$DOMAIN")
    ALL_DOMAINS+=("${FOUND_SUBS[@]}")
fi

if $RUN_SD_SCANB; then
    echo -e "${CYAN}[INFO]${RESET} Running advanced passive subdomain scan..."
    mapfile -t FOUND_SUBS < <(subfinder -silent -all -d "$DOMAIN")
    ALL_DOMAINS+=("${FOUND_SUBS[@]}")
fi

# Remove duplicates
ALL_DOMAINS=($(printf "%s\n" "${ALL_DOMAINS[@]}" | sort -u))

# Save & Display subdomains
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
SUB_FILE="reports/subdomains_$DOMAIN_$TIMESTAMP.txt"
printf "%s\n" "${ALL_DOMAINS[@]}" > "$SUB_FILE"

echo -e "${GREEN}[INFO]${RESET} Subdomains saved to: $SUB_FILE"

# ========================
# Labeled Domain Output
# ========================
echo -e "\n${GREEN}[INFO]${RESET} Domains to be scanned:"
echo -e "  ${CYAN}Main Domain:${RESET} $DOMAIN"

if [ ${#MANUAL_SUBS[@]} -gt 0 ]; then
    echo -e "  ${CYAN}Provided Subdomains:${RESET}"
    for sub in "${MANUAL_SUBS[@]}"; do
        echo -e "    - ${GREEN}$sub${RESET}"
    done
fi

if [ ${#FOUND_SUBS[@]} -gt 0 ]; then
    echo -e "  ${CYAN}Discovered Subdomains:${RESET}"
    for sub in "${FOUND_SUBS[@]}"; do
        echo -e "    - ${GREEN}$sub${RESET}"
    done
fi

# ========================
# Scan Function
# ========================
scan_domain() {
    local target=$1
    echo -e "${CYAN}[INFO]${RESET} Auditing $target"

    # WhatWeb
    echo -e "${CYAN}[INFO]${RESET} Running WhatWeb..."
    whatweb "$target" | sed "s/^\[.*\] /${GREEN}[WhatWeb]${RESET} /"

    # Nmap
    echo -e "${CYAN}[INFO]${RESET} Running Nmap..."
    nmap -sV --script vuln "$target" | sed "s/^|/${YELLOW}|${RESET}/" | sed "s/^$target/${CYAN}$target${RESET}/"

    # Nikto (background)
    echo -e "${CYAN}[INFO]${RESET} Running Nikto (background)..."
    if $TUNED_NIKTO; then
        nikto -h "$target" -Tuning 123456789abc -output "reports/nikto_${target}_${TIMESTAMP}.txt" &
    else
        nikto -h "$target" -output "reports/nikto_${target}_${TIMESTAMP}.txt" &
    fi
}

# ========================
# Run Scans
# ========================
for dom in "${ALL_DOMAINS[@]}"; do
    scan_domain "$dom"
done

wait
echo -e "${GREEN}[INFO]${RESET} All Nikto scans complete. Showing results:\n"

# ========================
# Color-Code Nikto Output
# ========================
while IFS= read -r line; do
    if [[ "$line" =~ (VULNERABLE|OSVDB|CVE|insecure|exploit) ]]; then
        echo -e "${RED}$line${RESET}"
    elif [[ "$line" =~ (warning|potentially) ]]; then
        echo -e "${YELLOW}$line${RESET}"
    elif [[ "$line" =~ (informational|INFO) ]]; then
        echo -e "${GREEN}$line${RESET}"
    else
        echo "$line"
    fi
done < <(grep -H "" reports/nikto_*_${TIMESTAMP}.txt)
