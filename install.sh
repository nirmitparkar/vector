#!/bin/bash
set -euo pipefail

GREEN='\033[0;32m'; BOLD='\033[1m'; RED='\033[0;31m'; NC='\033[0m'
ok()  { echo -e "  ${GREEN}✓${NC} $1"; }
die() { echo -e "\n${RED}ERROR:${NC} $1\n"; exit 1; }
hr()  { echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; }

[[ $EUID -eq 0 ]] || die "Run as root: sudo bash"

clear
hr
echo -e "${BOLD}        Vector App Installer${NC}"
hr
echo ""

# Ask for PAT (needed to download .deb from private repo)
read -rsp "  Enter GitHub PAT: " GH_PAT
echo ""
[[ -n "$GH_PAT" ]] || die "PAT cannot be empty."

# Get latest release
echo "  Fetching latest release..."
ASSET_ID=$(curl -sf \
  -H "Authorization: token $GH_PAT" \
  https://api.github.com/repos/VectorParkarDevOrg/vector-app-release/releases/latest \
  | grep -o '"id": [0-9]*' | sed -n '2p' | grep -o '[0-9]*')
[[ -n "$ASSET_ID" ]] || die "Invalid PAT or no release found."
ok "Release found."

# Add PostgreSQL repo if needed
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq curl gnupg lsb-release ca-certificates > /dev/null 2>&1
if ! apt-cache show postgresql-16 &>/dev/null; then
  echo "  Adding PostgreSQL repo..."
  curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc \
    | gpg --dearmor -o /usr/share/keyrings/postgresql-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/postgresql-keyring.gpg] https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" \
    > /etc/apt/sources.list.d/pgdg.list
  apt-get update -qq
  ok "PostgreSQL repo added."
fi

# Download .deb using PAT
echo "  Downloading package..."
curl -fsSL \
  -H "Authorization: token $GH_PAT" \
  -H "Accept: application/octet-stream" \
  -o /tmp/vector-app.deb \
  "https://api.github.com/repos/VectorParkarDevOrg/vector-app-release/releases/assets/${ASSET_ID}"
[[ $(wc -c < /tmp/vector-app.deb) -gt 10000 ]] || die "Download failed. Check PAT permissions."
ok "Package downloaded."

# Install
echo "  Installing (may take a few minutes)..."
apt-get install -y /tmp/vector-app.deb
rm -f /tmp/vector-app.deb

# Done
echo ""
hr
echo -e "${GREEN}${BOLD}  Installation complete!${NC}"
hr
echo ""
echo -e "  ${BOLD}URL      :${NC}  http://$(hostname -I | awk '{print $1}'):8090"
echo -e "  ${BOLD}Login    :${NC}  admin@example.com"
echo -e "  ${BOLD}Password :${NC}  admin"
echo ""
hr
echo -e "${BOLD}  Service Status:${NC}"
echo ""
systemctl status vector-backend nginx postgresql --no-pager | grep -E '●|Active:'
echo ""
