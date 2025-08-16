# Passive Domain & Subdomain Vulnerability Scanner

This script automates **subdomain discovery** and **security scanning** using:
- [subfinder](https://github.com/projectdiscovery/subfinder) (passive subdomain enumeration)
- [WhatWeb](https://github.com/urbanadventurer/WhatWeb) (web technology fingerprinting)
- [Nmap](https://nmap.org/) (port/service scan + vulnerability scripts)
- [Nikto](https://cirt.net/Nikto2) (web vulnerability scanner)

It color-codes results by severity and stores scan reports in the `reports/` directory.

Please note that you need to run this as root or else most checks will fail

---

## Command-Line Flags

| Flag | Long Form | Description |
|------|-----------|-------------|
| `-d` | `--domain` | **(Required)** The root domain to scan. |
| `-sd` | `--subdomains` | Comma-separated subdomains to include manually. |
| `-sdscan` | `--subdomain-scan` | Passive subdomain scan using `subfinder`. |
| `-sdscanb` | `--subdomain-scan-b` | Advanced passive subdomain scan using `subfinder -all`. |
| `-tn` | `--tuned-nikto` | Enable tuned Nikto scan (`-Tuning 123456789abc`). |
| `-h` | `--help` | Show usage information. |

---

## Script Workflow

1.  **Dependency Check**
    - Verifies installation of:
      - Go
      - subfinder
      - WhatWeb
      - Nmap
      - Nikto
    - If a dependency is missing, the script prompts to install it automatically.

2.  **Subdomain Collection**
    - **Always includes the main domain** in the scan.
    - Combines:
      - Manual subdomains from `-sd`
      - Passive scan results from `-sdscan` / `-sdscanb`
    - Deduplicates the list.
    - Saves final subdomains to a timestamped file in `reports/`.
    - Presents the final list categorized into **Main Domain**, **Provided Subdomains**, and **Discovered Subdomains**.

3.  **Scanning Each Target**
    - **WhatWeb**: Fingerprints web technologies.
    - **Nmap**: Runs service/version detection and vulnerability scripts.
    - **Nikto**: Runs in the background, scanning for web vulnerabilities.

4.  **Nikto Result Processing**
    - After all Nikto scans finish, results are displayed:
      - **Red** → High severity (`OSVDB`, `CVE`, `exploit`, `VULNERABLE`)
      - **Yellow** → Warnings / potential issues
      - **Green** → Informational messages

5.  **Report Storage**
    - All raw Nikto scan results are saved to the `reports/` directory.
    - The subdomain list is also saved for reference.
    - **The entire terminal output is logged to a timestamped file in the `reports/` directory.**

6.  **Timing**
    - **The script measures and reports the total time taken to complete all scans.**

---

## Example Usage

```bash
# Scan example.com, discover subdomains, run tuned Nikto
sudo ./site_audit.sh -d example.com -sdscan -tn

# Scan example.com with custom subdomains
sudo ./site_audit.sh -d example.com -sd [www.example.com](https://www.example.com),api.example.com
