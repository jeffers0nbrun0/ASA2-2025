# Firewall (Linux + iptables) — Documentação

Este repositório/documento descreve a política de firewall implementada no servidor **FIREWALL** do laboratório (Linux Mint/Ubuntu), usando **iptables** no formato **iptables-restore**.

A configuração foi pensada para:
- Proteger o próprio firewall (cadeia `INPUT`)
- Roteiar/NATear a rede interna **10.0.0.0/24** para a internet pela interface de gerência/WAN
- Preservar o acesso SSH pela interface de gerência (não derrubar a sessão)
- Implementar cadeias personalizadas e proteções contra abuso (SYN/bruteforce no SSH, limitação por IP, ban progressivo)
- Gerar logs padronizados para centralização no servidor **LOG (10.0.0.2)**

---

## 1) Arquitetura do laboratório

### Endereços e interfaces

**FIREWALL**
- WAN / Gerência: `enp0s3` — `192.169.2.10/28`
- LAN interna: `enp0s8` — `10.0.0.1/24`

**Demais servidores (LOG/AD/BANCO/SMTP)**
- WAN/Gerência: `enp0s3` — `192.169.2.11..14/28` (apenas acesso, sem default route)
- LAN interna: `enp0s8` — `10.0.0.2..5/24`

**Rede interna dos serviços:** `10.0.0.0/24`  
**Gateway interno:** `10.0.0.1` (FIREWALL)

> Observação: Somente o FIREWALL deve “sair” para a internet pela `enp0s3`. Os demais servidores não devem usar a `enp0s3` como rota padrão.

---

## 2) Objetivos do firewall

- **Tabela `filter`**
  - Políticas default **DROP** em `INPUT` e `FORWARD`
  - Permitir tráfego essencial e conexões já estabelecidas
  - Permitir **SSH de gerência** via `enp0s3` com proteções
  - Permitir tráfego da LAN para o firewall (pode ser refinado depois)
  - Roteamento LAN → WAN controlado

- **Tabela `nat`**
  - `MASQUERADE` de `10.0.0.0/24` saindo pela `enp0s3`

- **Cadeias personalizadas**
  - `PROTECAO_SSH` (anti-abuso + ban progressivo)
  - `TRAFEGO_INTERNO` (LAN ↔ LAN)
  - `LOG_DROP_IN` (log/drop para INPUT)
  - `LOG_DROP_FWD` (log/drop para FORWARD)
  - `LOG_SSH` (log/drop para eventos de proteção SSH)

- **Proteções**
  - Limite de conexões simultâneas por IP (`connlimit`)
  - Limite de novas conexões por IP (`hashlimit`) para mitigar SYN/bruteforce no SSH
  - Ban progressivo com `recent` (muitas tentativas em janela curta → bloqueio por 1 hora)

---

## 3) Arquivo principal

- `fw.v4` (iptables-restore)
  - Aplica regras nas tabelas `filter` e `nat`

Sugestão de caminho no firewall:
- `/root/fw.v4`

Aplicação:
```bash
sudo iptables-restore < /root/fw.v4
```

Backup antes de aplicar:
```bash
sudo iptables-save > /root/iptables.backup.$(date +%F-%H%M%S)
```

---

## 4) Pré-requisitos (roteamento)

Ativar encaminhamento IPv4:
```bash
sudo sysctl -w net.ipv4.ip_forward=1
echo 'net.ipv4.ip_forward=1' | sudo tee /etc/sysctl.d/99-ipforward.conf >/dev/null
```

Hardening básico recomendado:
```bash
cat <<'EOF' | sudo tee /etc/sysctl.d/99-fw-hardening.conf >/dev/null
net.ipv4.tcp_syncookies=1
net.ipv4.conf.all.rp_filter=1
net.ipv4.conf.default.rp_filter=1
net.ipv4.conf.all.accept_redirects=0
net.ipv4.conf.default.accept_redirects=0
net.ipv4.conf.all.send_redirects=0
net.ipv4.conf.default.send_redirects=0
EOF
sudo sysctl --system
```

---

## 5) Fluxo de tráfego (visão didática)

### 5.1 INPUT (tráfego destinado ao firewall)

1. Permite `lo` (loopback)
2. Permite `ESTABLISHED,RELATED`
3. Droppa `INVALID` com log (`LOG_DROP_IN`)
4. ICMP echo-request (ping) com rate-limit (opcional)
5. SSH de gerência em `enp0s3:22`
   - `NEW` passa por `PROTECAO_SSH`
   - demais pacotes (já estabelecidos) passam pela regra `ACCEPT`
6. Permite tráfego vindo da LAN `10.0.0.0/24` para o firewall (ajustável)
7. Todo o restante cai em `LOG_DROP_IN`

**Política final:** `INPUT DROP` por padrão.

### 5.2 FORWARD (tráfego roteado através do firewall)

1. Permite `ESTABLISHED,RELATED`
2. Droppa `INVALID` com log (`LOG_DROP_FWD`)
3. LAN ↔ LAN (`enp0s8` → `enp0s8`) passa por `TRAFEGO_INTERNO`
4. LAN → WAN (`enp0s8` → `enp0s3`) é permitido
5. Todo o restante cai em `LOG_DROP_FWD`

**Política final:** `FORWARD DROP` por padrão.

### 5.3 NAT (saída para internet)

Em `POSTROUTING`:
- `MASQUERADE` para origem `10.0.0.0/24` saindo pela `enp0s3`

---

## 6) Cadeias e implementações

### 6.1 LOG_DROP_IN / LOG_DROP_FWD / LOG_SSH
Cada cadeia faz:
- `LOG` com rate-limit (evita flood de log)
- `DROP` em seguida

Prefixos gerados (importante para centralização):
- `FWALL DROP_IN `
- `FWALL DROP_FWD `
- `FWALL SSH `

### 6.2 PROTECAO_SSH
Objetivo: proteger o SSH sem derrubar gerência legítima.

Implementa:
- **Ban por 1h** se IP estiver na lista `SSHBAN` (módulo `recent`)
- **connlimit**: bloqueia se IP tiver conexões simultâneas acima de um limite (ex.: 4)
- **recent (janela)**: se houver **12 tentativas em 5 min**, marca ban e bloqueia
- **hashlimit**: limita novas conexões por IP (ex.: 15/min burst 30)
- acima do limite → `LOG_SSH` (log + drop)

> Obs.: esses números são “default saudável” para laboratório. Em produção, ajuste conforme perfil de uso e volume real.

### 6.3 TRAFEGO_INTERNO
Por padrão, `ACCEPT` para tráfego entre hosts da LAN.  
Pode ser refinado no futuro (ex.: permitir só portas específicas entre servidores).

---

## 7) Centralização de logs (servidor LOG 10.0.0.2)

### 7.1 Conceito

O iptables envia mensagens para o **kernel log**, que o `rsyslog` coleta.  
Como os prefixos começam com `FWALL ...`, você consegue filtrar e separar.

Separação sugerida no servidor LOG:
- `/var/log/central/firewall/<HOST>/drops-input.log`
- `/var/log/central/firewall/<HOST>/drops-forward.log`
- `/var/log/central/firewall/<HOST>/ssh.log`

### 7.2 No FIREWALL (forward rsyslog)
Exemplo: encaminhar apenas logs que contenham `FWALL `:
```conf
if ($msg contains "FWALL ") then {
  action(type="omfwd" Target="10.0.0.2" Port="514" Protocol="tcp")
  # stop  # descomente se não quiser manter log local
}
```

### 7.3 No LOG (separação por arquivo)
Exemplo (rsyslog no 10.0.0.2), carregado **antes** de regras genéricas:
```conf
template(name="TmplFWDropIn"  type="string" string="/var/log/central/firewall/%HOSTNAME%/drops-input.log")
template(name="TmplFWDropFwd" type="string" string="/var/log/central/firewall/%HOSTNAME%/drops-forward.log")
template(name="TmplFWSsh"     type="string" string="/var/log/central/firewall/%HOSTNAME%/ssh.log")

if ($msg contains "FWALL DROP_IN ") then {
  action(type="omfile" dynaFile="TmplFWDropIn"  createDirs="on" dirCreateMode="0750" fileCreateMode="0640")
  stop
}
if ($msg contains "FWALL DROP_FWD ") then {
  action(type="omfile" dynaFile="TmplFWDropFwd" createDirs="on" dirCreateMode="0750" fileCreateMode="0640")
  stop
}
if ($msg contains "FWALL SSH ") then {
  action(type="omfile" dynaFile="TmplFWSsh"     createDirs="on" dirCreateMode="0750" fileCreateMode="0640")
  stop
}
```

---

## 8) Verificação rápida

### Ver regras carregadas
```bash
sudo iptables -S
sudo iptables -t nat -S
```

### Ver contadores (o que está “batendo”)
```bash
sudo iptables -L -n -v
sudo iptables -L -n -v FORWARD
```

### Testar NAT e roteamento
- De um servidor na LAN (ex.: 10.0.0.2), rota default deve ser 10.0.0.1
- Teste:
```bash
ping -c 2 10.0.0.1
curl -I https://example.com
```

### Testar SSH de gerência
- Do teu host de gerência, conecte no IP de gerência do firewall (`192.169.2.10`) na porta do SSH:
```bash
ssh usuario@192.169.2.10
```

---

## 9) Rollback (se algo der errado)

Se você salvou backup antes:
```bash
sudo iptables-restore < /root/iptables.backup.YYYY-MM-DD-HHMMSS
```

Dica: em ambientes de laboratório, vale usar rollback automático com `at` antes de aplicar mudanças.

---

## Referência do arquivo `fw.v4`

O `fw.v4` implementa exatamente o fluxo descrito acima e utiliza os prefixos `FWALL ...` para facilitar a centralização e separação de logs.
