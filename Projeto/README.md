# Projeto Final – Administração Avançada de Serviços de Rede (IFRN)

Este repositório documenta a implantação de um **ambiente corporativo** em laboratório, com foco em **segurança**, **autenticação centralizada**, **controle de permissões**, **serviços de infraestrutura** e **banco de dados com backup/restauração**.

## 1. Objetivos atendidos (visão rápida)

- **Permissões avançadas (ACLs)**: diretórios por departamento + usuários/grupos + conflito real de máscara.
- **Netfilter/Firewall (sem DNAT)**: filter + nat (SNAT/MASQUERADE), cadeias personalizadas e proteções (rate-limit, SYN, bloqueio progressivo).
- **NTP**: servidor NTP interno (com fontes públicas) e clientes apontando para o NTP local.
- **Logs**: syslog centralizado por host e por serviço (TCP/514), regras de filtragem e organização em `/var/log/central/...`.
- **Diretório/Autenticação**: **Samba 4 AD DC** (LDAP/Kerberos) com OUs/grupos/usuários e compartilhamentos departamentais.
- **Banco de Dados**: MariaDB com entidades corporativas + CRUD + **2 métodos de backup** + restauração validada.

> Observação: Serviços de **SMTP + antivírus** podem existir no ambiente conforme topologia (SRV3), mas a documentação e evidências dependem do que foi efetivamente validado no laboratório.

---

## 2. Topologia do laboratório (servidores e papéis)

| Host                       |            IP | Função                                                                      |
| -------------------------- | ------------: | --------------------------------------------------------------------------- |
| **SRV2 – Firewall**        | `10.0.0.1/24` | Gateway, Netfilter (filter/nat), proteção SSH, logging de drops             |
| **SRV5 – Logs/NTP**        | `10.0.0.2/24` | Syslog central (rsyslog TCP/514), organização por host/serviço, NTP interno |
| **SRV1 – AD/LDAP (Samba)** | `10.0.0.3/24` | Samba 4 como **AD DC**, DNS interno, Kerberos, OUs/grupos/usuários          |
| **SRV4 – Banco**           | `10.0.0.4/24` | MariaDB: schema corporativo, CRUD, backups e restores                       |
| **SRV3 – SMTP + AV**       | `10.0.0.5/24` | Serviço de e-mail/antivírus (quando aplicável no laboratório)               |

---

## 3. Entregas por requisito

### 3.1 Permissões avançadas (ACLs)

**Estrutura corporativa:**

```
/srv/empresa/
├── ti
├── financeiro
└── comercial
```

- ACLs configuradas por grupo departamental (TI/Financeiro/Comercial).
- Usuários distribuídos por departamento para validação.
- Conflito real documentado: **máscara ACL** limitando permissões efetivas e solução via `setfacl -m mask::rwx`.

📄 Documentação detalhada: **README_SAMBA_AD.md** (seção ACLs).

---

### 3.2 Netfilter / Firewall (sem DNAT)

- Políticas padrão: `INPUT DROP`, `FORWARD DROP`, `OUTPUT ACCEPT`.
- Cadeias personalizadas (exemplos): `PROTECAO_SSH`, `TRAFEGO_INTERNO`, `LOG_DROP_IN`, `LOG_DROP_FWD`, `LOG_SSH`.
- Proteções:
  - `connlimit` (limite de conexões simultâneas por IP)
  - `hashlimit` (rate-limit de NEW no SSH)
  - `recent` (bloqueio progressivo por repetição)
- NAT: `MASQUERADE` para saída LAN → WAN.

---

### 3.3 NTP (sincronização)

- Servidor NTP interno no **SRV5 (10.0.0.2)** com múltiplas fontes públicas e fallback.
- Clientes (demais servidores) apontando para o NTP interno.

---

### 3.4 Serviços de Log (Syslog central)

- Servidor centralizado recebendo via **TCP/514**.
- Organização por host e por serviço em:
  - `/var/log/central/<serviço>/<HOSTNAME>/syslog.log` (padrão recomendado)
- Exemplo de serviços/logs organizados:
  - `firewall/` (drops-input, drops-forward, ssh)
  - `ntp/`
  - `mariadb/`
  - `postfix/` (quando aplicável)
  - `antivirus/` (quando aplicável)

---

### 3.5 Autenticação e armazenamento (LDAP/AD/Samba)

Implementado via **Samba 4 AD DC**:

- Domínio: `ADSERVER.LOCAL`
- Host: `dc-adserver`
- OUs: `ti`, `financeiro`, `comercial`
- Grupos: `ti`, `financeiro`, `comercial`
- Usuários: 3 por departamento (exemplo no README)
- Compartilhamentos:
  - `[TI]`, `[Financeiro]`, `[Comercial]` com `valid users = @grupo`

📄 Documentação completa (instalação + configuração + testes): **README_SAMBA_AD.md**.

---

### 3.6 Antivírus corporativo (se aplicável no lab)

- Estrutura prevista para integração com SMTP (varredura de anexos).
- Validação típica: assinatura **EICAR** e evidências em logs.

---

### 3.7 SMTP corporativo (se aplicável no lab)

- Estrutura prevista: contas reais, aliases, domínio virtual, Maildir, antispam e evidências de envio/recebimento.

---

### 3.8 Banco de Dados (MariaDB) – CRUD + backups/restores

- Banco corporativo com entidades dos setores (TI/Financeiro/Comercial).
- CRUD completo demonstrado.
- **Dois métodos de backup**:
  - Dump lógico (`mysqldump`)
  - Backup físico (mariadb-backup / cópia consistente)
- Restauração funcional e checagem de integridade/consistência.

📄 Documentação detalhada: **README_BACKUP_RESTORE.md** (+ complemento, se existir).

---

## 4. Integrações realizadas (resumo)

- **Firewall → Logs**: logs de drops/proteções enviados ao syslog central.
- **Banco → Logs**: logs do MariaDB centralizados no syslog (via rsyslog).
- **Todos → NTP**: sincronização via servidor NTP interno.
- **AD DC**: autenticação centralizada para recursos (Samba/LDAP/Kerberos).
- **DB**: base corporativa consumida por serviços que precisarem (ex.: SMTP/relatórios).

---

## 5. Testes e validação (comandos sugeridos)

### 5.1 Syslog central (SRV5)

```bash
ss -lntp | grep ':514'
tail -n 200 /var/log/central/mariadb/*/syslog.log
```

### 5.2 MariaDB (SRV4)

```bash
systemctl status mariadb --no-pager
mariadb -u dbroot -p -e "SHOW DATABASES;"
```

### 5.3 Samba AD DC (SRV1)

```bash
systemctl status samba-ad-dc --no-pager
samba-tool ou list
kinit administrator@ADSERVER.LOCAL && klist
```

### 5.4 Firewall (SRV2)

```bash
iptables -S
iptables -t nat -S
journalctl -k -g "FWALL" -n 50 --no-pager
```

### 5.5 NTP (SRV5 e clientes)

```bash
chronyc sources -v
chronyc tracking
```

---

## 7. Referências

- Samba: https://www.samba.org/samba/docs/
- rsyslog: https://www.rsyslog.com/doc/
- MariaDB: https://mariadb.com/kb/
- Netfilter/Iptables: https://netfilter.org/documentation/
