#!/bin/bash

echo ""
echo -n "Enter GitHub PAT: "
read -rs GH_PAT
echo ""

# Download
ASSET_ID=$(curl -sf -H "Authorization: token $GH_PAT" \
  https://api.github.com/repos/VectorParkarDevOrg/vector-app-release/releases/latest \
  | grep -o '"id": [0-9]*' | sed -n '2p' | grep -o '[0-9]*')

curl -fsSL \
  -H "Authorization: token $GH_PAT" \
  -H "Accept: application/octet-stream" \
  -o /tmp/vector-app.deb \
  "https://api.github.com/repos/VectorParkarDevOrg/vector-app-release/releases/assets/${ASSET_ID}"

# Add PostgreSQL repo if needed
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

# Install
apt-get install -y /tmp/vector-app.deb
rm -f /tmp/vector-app.deb

# Result
echo ""
echo "================================"
echo " URL      : http://$(hostname -I | awk '{print $1}'):8090"
echo " Login    : admin@example.com"
echo " Password : admin"
echo "================================"
echo ""
systemctl status vector-backend nginx postgresql --no-pager | grep -E '●|Active:'
