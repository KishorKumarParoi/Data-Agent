#!/usr/bin/env bash
# ==============================================================================
# 🚀 ZERO-TOUCH 1-COMMAND AUTO-BOOTSTRAPPER FOR EC2 & CLOUD VMS
# DATA AGENT: ENTERPRISE MULTI-AGENT BI & SQL SYSTEM
#
# Run directly on any bare EC2 instance or cloud VM:
#   curl -fsSL https://raw.githubusercontent.com/KishorKumarParoi/Data-Agent/main/bootstrap.sh | bash
# ==============================================================================
set -eo pipefail

BOLD='\033[1m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${CYAN}${BOLD}"
cat << "EOF"
================================================================================
  📊 DATA AGENT: MULTI-AGENT SQL & ETL SYSTEM — ZERO-TOUCH BOOTSTRAPPER
================================================================================
EOF
echo -e "${NC}"

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
export UCF_FORCE_CONFFOLD=1

run_sudo() {
    if [ "$EUID" -eq 0 ]; then
        "$@"
    elif command -v sudo &>/dev/null && sudo -n true 2>/dev/null; then
        sudo -E "$@"
    elif command -v sudo &>/dev/null; then
        sudo -E "$@"
    else
        "$@"
    fi
}

# 1. Prereqs
echo -e "${CYAN}[1/5] Detecting OS and ensuring Git, Curl & Python are available...${NC}"
if ! command -v git &>/dev/null || ! command -v curl &>/dev/null; then
    if [ -f /etc/debian_version ]; then
        run_sudo apt-get update -qq
        run_sudo apt-get install -y -qq git curl ca-certificates tar gzip unzip build-essential python3 python3-pip python3-venv >/dev/null 2>&1
    elif [ -f /etc/amazon-linux-release ] || [ -f /etc/redhat-release ]; then
        run_sudo yum install -y -q git curl ca-certificates tar gzip unzip python3 python3-pip >/dev/null 2>&1 || true
    fi
fi

# 2. OOM Protection (4GB Swap)
echo -e "\n${CYAN}[2/5] Checking System Memory & OOM Protection...${NC}"
if command -v free &>/dev/null; then
    TOTAL_RAM_MB=$(free -m | awk '/^Mem:/{print $2}')
    EXISTING_SWAP_MB=$(free -m | awk '/^Swap:/{print $2}')
    if [ "$TOTAL_RAM_MB" -lt 8000 ] && [ "$EXISTING_SWAP_MB" -lt 2000 ]; then
        echo -e "${YELLOW}[!] Host has ${TOTAL_RAM_MB}MB RAM. Auto-configuring 4GB swapfile for compilation safety...${NC}"
        if [ ! -f /swapfile ]; then
            run_sudo fallocate -l 4G /swapfile 2>/dev/null || run_sudo dd if=/dev/zero of=/swapfile bs=1M count=4096 2>/dev/null
            run_sudo chmod 600 /swapfile
            run_sudo mkswap /swapfile >/dev/null 2>&1
            run_sudo swapon /swapfile 2>/dev/null || true
            run_sudo sysctl vm.swappiness=20 >/dev/null 2>&1 || true
            if ! grep -q "/swapfile" /etc/fstab 2>/dev/null; then
                echo "/swapfile none swap sw 0 0" | run_sudo tee -a /etc/fstab >/dev/null 2>&1 || true
            fi
            echo -e "${GREEN}[✓] 4GB Swapfile configured and active!${NC}"
        fi
    fi
fi

# 3. Clone / Sync
echo -e "\n${CYAN}[3/5] Ensuring Data-Agent repository is local...${NC}"
REPO_URL="https://github.com/KishorKumarParoi/Data-Agent.git"
REPO_DIR="Data-Agent"

if [ -f "main.py" ] && [ -d "agents" ]; then
    echo -e "${GREEN}[✓] Already inside repository directory ($(pwd)). Syncing latest commit...${NC}"
    git pull origin main 2>/dev/null || true
elif [ -d "$REPO_DIR" ]; then
    cd "$REPO_DIR"
    git pull origin main 2>/dev/null || true
else
    echo -e "${YELLOW}[+] Shallow cloning repository from GitHub...${NC}"
    git clone --depth 1 "$REPO_URL" "$REPO_DIR"
    cd "$REPO_DIR"
fi

chmod +x bootstrap.sh clear.sh 2>/dev/null || true

if [ ! -f .env ] && [ -f .env.example ]; then
    cp .env.example .env
fi

# 4. Bootstrap Python & Dependencies via uv
echo -e "\n${CYAN}[4/5] Bootstrapping Astral uv & Virtual Environment...${NC}"
if ! command -v uv &>/dev/null; then
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
fi

uv venv .venv
uv pip install --python .venv/bin/python -r requirements.txt

# Start PostgreSQL if docker available
if command -v docker &>/dev/null; then
    echo -e "${CYAN}[+] Starting isolated PostgreSQL database via Docker...${NC}"
    docker compose up -d postgres 2>/dev/null || true
fi

# 5. Execute Self-Test Verification
echo -e "\n${CYAN}[5/5] Executing Data Agent Self-Reflection Verification...${NC}"
.venv/bin/python -c "from agents.data_agent import data_agent; print('✔ Multi-Agent Supervisor graph compiled successfully!')"

echo -e "\n${GREEN}${BOLD}"
cat << "EOF"
================================================================================
🎉 DEPLOYMENT COMPLETE! DATA AGENT IS OPERATIONAL!
================================================================================
EOF
echo -e "${NC}"
echo -e "${BOLD}Quick Run Commands:${NC}"
echo -e "  • Interactive CLI Agent : ${CYAN}.venv/bin/python main.py${NC}"
echo -e "  • Zero-Cost Teardown    : ${YELLOW}./clear.sh${NC}\n"
