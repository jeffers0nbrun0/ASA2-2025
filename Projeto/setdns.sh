cat <<'EOF' | sudo tee /usr/local/sbin/set-ad-dns.sh >/dev/null
#!/usr/bin/env bash
set -euo pipefail

DNS_IP="10.0.0.3"
DOMAIN="adserver.local"
HOSTS_LINE="hosts:          files dns mdns4_minimal myhostname"

ts="$(date +%Y%m%d-%H%M%S)"
backup_dir="/root/backup-ad-dns-$ts"
mkdir -p "$backup_dir"

backup_file() {
  local f="$1"
  if [[ -e "$f" || -L "$f" ]]; then
    cp -a "$f" "$backup_dir"/
  fi
}

set_nsswitch() {
  local f="/etc/nsswitch.conf"
  backup_file "$f"

  if grep -qE '^[[:space:]]*hosts:' "$f"; then
    sed -i -E "s|^[[:space:]]*hosts:.*|$HOSTS_LINE|" "$f"
  else
    echo "$HOSTS_LINE" >> "$f"
  fi

  echo "[OK] Ajustado $f (linha hosts:)"
}

configure_systemd_resolved() {
  local dropin_dir="/etc/systemd/resolved.conf.d"
  local dropin_file="$dropin_dir/10-adserver.conf"

  mkdir -p "$dropin_dir"
  backup_file "/etc/systemd/resolved.conf"
  backup_file "$dropin_file"
  backup_file "/etc/resolv.conf"

  cat > "$dropin_file" <<EOC
[Resolve]
DNS=$DNS_IP
Domains=$DOMAIN
EOC

  systemctl restart systemd-resolved

  if command -v resolvectl >/dev/null 2>&1; then
    resolvectl flush-caches || true
  fi

  echo "[OK] systemd-resolved configurado (DNS=$DNS_IP, Domains=$DOMAIN)"
}

configure_static_resolvconf() {
  backup_file "/etc/resolv.conf"

  if [[ -L /etc/resolv.conf ]]; then
    rm -f /etc/resolv.conf
  fi

  cat > /etc/resolv.conf <<EOR
nameserver $DNS_IP
search $DOMAIN
options edns0 trust-ad
EOR

  echo "[OK] /etc/resolv.conf configurado de forma estática"
}

main() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo "Execute como root: sudo $0"
    exit 1
  fi

  echo "[INFO] Backup em: $backup_dir"

  set_nsswitch

  if command -v systemctl >/dev/null 2>&1 && systemctl list-unit-files 2>/dev/null | grep -q '^systemd-resolved\.service'; then
    if systemctl is-active --quiet systemd-resolved 2>/dev/null; then
      configure_systemd_resolved
    else
      echo "[WARN] systemd-resolved existe mas não está ativo. Vou usar /etc/resolv.conf estático."
      configure_static_resolvconf
    fi
  else
    echo "[WARN] systemd-resolved não encontrado. Vou usar /etc/resolv.conf estático."
    configure_static_resolvconf
  fi

  echo
  echo "[TESTE] Linha hosts atual:"
  grep '^hosts:' /etc/nsswitch.conf || true

  echo
  echo "[TESTE] Resolução via libc (getent):"
  getent hosts "$DOMAIN" || true

  echo
  echo "[TESTE] Ping (se ICMP não estiver bloqueado):"
  ping -c 2 "$DOMAIN" || true

  echo
  echo "[DONE] Se precisar voltar, os backups estão em: $backup_dir"
}

main "$@"
EOF

sudo chmod +x /usr/local/sbin/set-ad-dns.sh
sudo /usr/local/sbin/set-ad-dns.sh
