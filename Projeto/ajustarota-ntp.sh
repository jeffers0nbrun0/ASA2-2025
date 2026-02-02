cat <<'EOF' > /tmp/setup-chrony-client.sh
#!/usr/bin/env bash
set -euo pipefail

NTP_SERVER="10.0.0.2"
WAN_DEV="enp0s3"
LAN_DEV="enp0s8"

echo "[0] Detectando conexões do NetworkManager para $WAN_DEV e $LAN_DEV..."
WAN_CON="$(nmcli -t -f NAME,DEVICE con show --active | awk -F: -v d="$WAN_DEV" '$2==d{print $1; exit}')"
LAN_CON="$(nmcli -t -f NAME,DEVICE con show --active | awk -F: -v d="$LAN_DEV" '$2==d{print $1; exit}')"

if [[ -z "${WAN_CON}" || -z "${LAN_CON}" ]]; then
  echo "ERRO: não consegui identificar as conexões ativas."
  echo "Conexões ativas:"
  nmcli -t -f NAME,DEVICE con show --active
  echo
  echo "Dica: ver todas as conexões:"
  echo "  nmcli con show"
  exit 1
fi

echo "WAN_CON=\"$WAN_CON\" (device $WAN_DEV)"
echo "LAN_CON=\"$LAN_CON\" (device $LAN_DEV)"

echo "[1/5] Instalando chrony..."
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update -y
sudo apt-get install -y chrony

CONF="/etc/chrony/chrony.conf"
BK="/etc/chrony/chrony.conf.bak.$(date +%F-%H%M%S)"

echo "[2/5] Backup do chrony.conf em: $BK"
sudo cp -a "$CONF" "$BK"

echo "[3/5] Configurando chrony: comentar 'pool' e usar server ${NTP_SERVER}..."
sudo sed -i -E 's/^[[:space:]]*(pool[[:space:]].*)$/# \1/' "$CONF"
sudo sed -i -E "/^[[:space:]]*server[[:space:]]+${NTP_SERVER//./\\.}[[:space:]]+/d" "$CONF"

tmp="$(mktemp)"
{
  echo "server ${NTP_SERVER} iburst prefer"
  echo
  cat "$CONF"
} > "$tmp"
sudo tee "$CONF" >/dev/null < "$tmp"
rm -f "$tmp"

sudo grep -qE '^[[:space:]]*makestep[[:space:]]+' "$CONF" || echo "makestep 1.0 3" | sudo tee -a "$CONF" >/dev/null
sudo grep -qE '^[[:space:]]*rtcsync[[:space:]]*$' "$CONF" || echo "rtcsync" | sudo tee -a "$CONF" >/dev/null

echo "[4/5] Ajustando rotas via NetworkManager (LAN default, WAN sem default)..."
sudo nmcli con mod "$LAN_CON" ipv4.never-default no ipv4.route-metric 100
sudo nmcli con mod "$WAN_CON" ipv4.never-default yes ipv4.route-metric 500

echo "Recarregando conexões..."
sudo nmcli con up "$LAN_CON" >/dev/null 2>&1 || true
sudo nmcli con up "$WAN_CON" >/dev/null 2>&1 || true

echo "[5/5] Reiniciando chrony e mostrando status..."
sudo systemctl restart chrony
sleep 2

echo
echo "=== Rotas (ip r) ==="
ip r || true

echo
echo "=== Chrony tracking ==="
chronyc tracking || true

echo
echo "=== Chrony sources ==="
chronyc sources -v || true

echo
echo "OK ✅ (backup: $BK)"
EOF

chmod +x /tmp/setup-chrony-client.sh
sudo /tmp/setup-chrony-client.sh
