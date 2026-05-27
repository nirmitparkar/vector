#!/bin/bash

echo ""

# Accept PAT from env var or prompt interactively
if [ -z "${GH_PAT:-}" ]; then
  echo -n "Enter GitHub PAT: "
  if [ -t 0 ]; then
    read -rs GH_PAT
  elif [ -c /dev/tty ]; then
    read -rs GH_PAT </dev/tty
  fi
  echo ""
fi

if [ -z "${GH_PAT:-}" ]; then
  echo "ERROR: PAT required. Run: GH_PAT=your_token bash /tmp/install.sh"
  exit 1
fi

# Validate PAT and get asset ID
echo "Validating token..."
RESPONSE=$(curl -sf \
  -H "Authorization: token $GH_PAT" \
  https://api.github.com/repos/VectorParkarDevOrg/vector-app-release/releases/latest 2>&1)

if [ -z "$RESPONSE" ]; then
  echo "ERROR: Invalid PAT or no access to repo. Make sure your token has 'repo' scope."
  exit 1
fi

ASSET_ID=$(echo "$RESPONSE" | python3 -c "
import sys, json
try:
  data = json.load(sys.stdin)
  for a in data.get('assets', []):
    if a['name'].endswith('.deb'):
      print(a['id'])
      break
except:
  pass
")

if [ -z "$ASSET_ID" ]; then
  echo "ERROR: Could not find .deb in release. Check PAT permissions."
  exit 1
fi

echo "Downloading package..."
curl -fsSL \
  -H "Authorization: token $GH_PAT" \
  -H "Accept: application/octet-stream" \
  -o /tmp/vector-app.deb \
  "https://api.github.com/repos/VectorParkarDevOrg/vector-app-release/releases/assets/${ASSET_ID}"

if [ "$(wc -c < /tmp/vector-app.deb)" -lt 10000 ]; then
  echo "ERROR: Download failed — file too small. Check PAT has 'repo' scope."
  exit 1
fi

echo "Setting up repositories..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq gnupg lsb-release ca-certificates

if ! apt-cache show postgresql-16 &>/dev/null; then
  curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc \
    | gpg --dearmor -o /usr/share/keyrings/postgresql-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/postgresql-keyring.gpg] https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" \
    > /etc/apt/sources.list.d/pgdg.list
  apt-get update -qq
fi

echo "Installing..."
apt-get install -y /tmp/vector-app.deb
rm -f /tmp/vector-app.deb

echo ""
echo "================================"
echo " URL      : http://$(hostname -I | awk '{print $1}'):8090"
echo " Login    : admin@example.com"
echo " Password : admin"
echo "================================"
echo ""
systemctl status vector-backend nginx postgresql --no-pager | grep -E '●|Active:'
