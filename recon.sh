#!/usr/bin/env bash

# ===================================
# Recon Script (Subfinder + Nmap)
# ===================================

### Color Codes ###
RED='\e[0;31m'
GREEN='\e[0;32m'
YELLOW='\e[0;33m'
BLUE='\e[0;34m'
MAGENTA='\e[0;35m'
NC='\e[0m' # No Color

### Sudo Check ###
if [[ $EUID -ne 0 ]]; then
    exec sudo "$0" "$@"
fi

### Atributes Check ###
if [ -z "$1" ]; then
        echo -e "${RED}[-] Usage: $0 <target>${NC}"
        exit 1
fi

### Ascii Banner ###
figlet Recon Script

depend_list=("curl" "mtr" "nmap" "dig" "subfinder")

for prog in "${depend_list[@]}"; do
	if ! command -v "$prog" > /dev/null 2>&1; then
		echo -e "${RED}[-] Required command $prog is not installed.${NC}"
		echo -e "${YELLOW}[*] Installing $prog...${NC}"
    sudo apt update > /dev/null 2>&1 && sudo apt upgrade -y > /dev/null 2>&1
      for not_inst in "${prog}"; do
        sudo apt install $not_inst -y > /dev/null 2>&1
      done
	else
		echo -e "${GREEN}[+] $prog is installed.${NC}"
	fi
done

### Aliases ###
TARGET="$1"
LABELS=$(echo "$TARGET" | awk -F'.' '{print NF}')
TIME=$(date +"%F_%H-%M-%S")
LOG_FILE="${TARGET}_${TIME}.log"
DNS_LOOKUP=$(dig +short "${TARGET}")

### Functions ###
nmap_scan() {
    echo -e "${YELLOW}[*] Executing Nmap...${NC}\n" | tee -a "${LOG_FILE}"
    sudo nmap -sC -sV -O -T4 "${TARGET}" >> "${LOG_FILE}"
}
short_ns() {
    NS=$(dig +short NS $TARGET)
    for ns in $NS; do
      IP=$(dig +short "$ns")
      for ip in $IP; do
        echo "$ns ---> $ip"
      
      done
    
    done
}
ip_addr() {
  dig +short "${TARGET}" | head -n 1 
}

### Main Commands ###
echo -e "${YELLOW}[*] DNS Resolving...${NC}" | tee -a "${LOG_FILE}"

if [ -z "${DNS_LOOKUP}" ]; then
    echo -e "${RED}[-] Could Not Resolve ${TARGET}"
    exit 1
else
    dig "${TARGET}" >> "${LOG_FILE}"
fi

echo -e "${YELLOW}[*] Traceroute To Destination...${NC}" | tee -a "${LOG_FILE}"

echo "" >> "${LOG_FILE}"

mtr -rw "${TARGET}" >> "${LOG_FILE}" || echo -e "${RED}[-] Network is down or ICMP ping disabled...${NC}" | tee -a "${LOG_FILE}"

echo "" >> "${LOG_FILE}"

echo -e "${YELLOW}[*] GeoIP Discovery...${NC}" | tee -a "${LOG_FILE}"

echo "" >> "${LOG_FILE}"

IP_ADDR=$(ip_addr) 

curl -s ipinfo.io/"${IP_ADDR}" | grep -E "city|region|country" >> "${LOG_FILE}"

echo "" >> "${LOG_FILE}"

if [ "$LABELS" -eq 2 ]; then
      
      echo -e "${YELLOW}[*] Searching for Name Servers...${NC}" | tee -a "${LOG_FILE}"

      dig NS "${TARGET}" >> "${LOG_FILE}"
 
      echo -e "${YELLOW}[*] Starting SubDomains Enumeration...${NC}" | tee -a "${LOG_FILE}"

      echo "" >> "${LOG_FILE}"

      subfinder -d "${TARGET}" -silent >> "${LOG_FILE}"

      echo "" >> "${LOG_FILE}"

      nmap_scan

else

      nmap_scan  

fi

echo -e "${GREEN}[+] Reconnaissance Completed! Results saved in $LOG_FILE${NC}"

### SUMMARY ###
echo -e "\n${BLUE}===== Reconnaissance Summary =====\n${NC}" | tee -a "$LOG_FILE"
echo -e "${BLUE}IP:${NC}" | tee -a "$LOG_FILE"
ip_addr | tee -a "$LOG_FILE"
echo -e "${BLUE}Ports: ${NC}" | tee -a "$LOG_FILE"
grep -E 'open' "$LOG_FILE" | tee -a "$LOG_FILE"
echo -e "${BLUE}NameServers: ${NC}" | tee -a "${LOG_FILE}"
short_ns | tee -a "${LOG_FILE}"
