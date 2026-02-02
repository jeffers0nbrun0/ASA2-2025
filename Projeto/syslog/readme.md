# Implementação do Syslog Centralizado

Este documento descreve como foi implementado o **Syslog centralizado** no ambiente do laboratório, permitindo a coleta, armazenamento e análise de logs do **Firewall**, **AD (Samba 4)**, **SMTP (Postfix/SpamAssassin/ClamAV)**, **Antivírus (scans/scripts)** e **NTP (Chrony)** de forma organizada e auditável.

---

## 1. Objetivo

- Centralizar logs de serviços críticos (Firewall, AD, SMTP, antivírus e NTP)
- Facilitar troubleshooting e auditoria
- Manter histórico confiável para análise de incidentes
- Separar logs por **host** e por **serviço**
- Permitir escalabilidade futura (ELK / Graylog / Loki)

---

## 2. Arquitetura de Logs

- **Servidor LOG (Syslog Central / NTP)**: `10.0.0.2`
- Servidores que enviam logs:
  - **FIREWALL**: `10.0.0.1`
  - **AD (Samba 4 AD DC)**: `10.0.0.3`
  - **BANCO**: `10.0.0.4`
  - **SMTP**: `10.0.0.5`

**Diretório central de logs**: `/var/log/central/`

Estratégia de armazenamento:
- Por host: `/var/log/central/<HOSTNAME>/...`
- Por categoria/serviço (quando faz sentido):
  - `/var/log/central/firewall/<HOSTNAME>/...`
  - `/var/log/central/antivirus/<HOSTNAME>/...`
  - `/var/log/central/ad/<HOSTNAME>/...`
  - `/var/log/central/ntp/<HOSTNAME>/...`

Fluxo simplificado:

Serviços (Firewall/AD/SMTP/NTP/AV)  
→ rsyslog (cliente)  
→ rsyslog (LOG 10.0.0.2)  
→ `/var/log/central/...`

---

## 3. Configuração do rsyslog (Servidor Central)

### 3.1 Habilitar recepção de logs remotos (UDP e TCP)

Arquivo: `/etc/rsyslog.conf` ou `/etc/rsyslog.d/10-server.conf`

```conf
module(load="imudp")
input(type="imudp" port="514")

module(load="imtcp")
input(type="imtcp" port="514")
```

> Recomendação: preferir **TCP** para logs críticos (evita perdas em picos).

---

## 4. Estrutura de Diretórios

Criação do diretório central e permissões:

```bash
mkdir -p /var/log/central
chown syslog:adm /var/log/central
chmod 750 /var/log/central
```

Estruturas adicionais por categoria:

```bash
mkdir -p /var/log/central/{firewall,antivirus,ad,ntp}
chown -R syslog:adm /var/log/central
chmod -R 750 /var/log/central
```

---

## 5. Configuração dos Clientes (todos os servidores)

Em cada servidor cliente (FIREWALL, AD, BANCO, SMTP), criar um forward para o LOG:

Arquivo: `/etc/rsyslog.d/60-forward.conf`

```conf
*.* @@10.0.0.2:514
```

Reiniciar:

```bash
systemctl restart rsyslog
```

> Quando for desejado “enviar somente alguns logs”, usar filtros (por tag, facility, programname) ao invés de `*.*`.

---

## 6. Separação de Logs por Host (padrão base)

No servidor LOG, o padrão recomendado é separar por host, criando:

- `/var/log/central/<HOSTNAME>/syslog.log`
- `/var/log/central/<HOSTNAME>/postfix.log` (quando aplicável)

Exemplo de template base:

```conf
template(name="TmplDefaultFile" type="string"
         string="/var/log/central/%HOSTNAME%/syslog.log")

*.* action(type="omfile" dynaFile="TmplDefaultFile")
```

---

## 7. Logs do SMTP (Postfix, ClamAV, SpamAssassin)

### 7.1 Postfix

O Postfix envia logs automaticamente via syslog (programname `postfix/...`).

No servidor LOG, regra para separar Postfix:

```conf
template(name="TmplPostfixFile" type="string"
         string="/var/log/central/%HOSTNAME%/postfix.log")

if ($programname startswith "postfix/") then {
  action(type="omfile" dynaFile="TmplPostfixFile")
  stop
}
```

### 7.2 ClamAV

ClamAV pode enviar logs via syslog usando `LogSyslog`.

Exemplo (clamd.conf):

```conf
LogSyslog true
LogFacility LOG_LOCAL6
```

No servidor LOG, separar `local6` para antivírus:

```conf
template(name="TmplAntivirusFile" type="string"
         string="/var/log/central/antivirus/%HOSTNAME%/clamav.log")

if ($syslogfacility-text == "local6") then {
  action(type="omfile" dynaFile="TmplAntivirusFile" createDirs="on")
  stop
}
```

### 7.3 SpamAssassin

Geralmente aparece como `spamd`. Regra típica:

```conf
template(name="TmplSpamFile" type="string"
         string="/var/log/central/%HOSTNAME%/spamassassin.log")

if ($programname contains "spamd") then {
  action(type="omfile" dynaFile="TmplSpamFile")
  stop
}
```

---

## 8. Logs do Firewall (iptables)

No FIREWALL, regras iptables geram logs via kernel/syslog com prefixos definidos.

Prefixos adotados:
- `FWALL DROP_IN `
- `FWALL DROP_FWD `
- `FWALL SSH `

No servidor LOG, separação em arquivos específicos:

```conf
template(name="TmplFWDropIn"  type="string" string="/var/log/central/firewall/%HOSTNAME%/drops-input.log")
template(name="TmplFWDropFwd" type="string" string="/var/log/central/firewall/%HOSTNAME%/drops-forward.log")
template(name="TmplFWSsh"     type="string" string="/var/log/central/firewall/%HOSTNAME%/ssh.log")

if ($msg contains "FWALL DROP_IN ") then {
  action(type="omfile" dynaFile="TmplFWDropIn" createDirs="on")
  stop
}
if ($msg contains "FWALL DROP_FWD ") then {
  action(type="omfile" dynaFile="TmplFWDropFwd" createDirs="on")
  stop
}
if ($msg contains "FWALL SSH ") then {
  action(type="omfile" dynaFile="TmplFWSsh" createDirs="on")
  stop
}
```

Teste manual (no firewall):

```bash
logger -t fw-test -p kern.warning "FWALL DROP_IN teste de log"
```

---

## 9. Logs do AD (Samba 4)

O AD (Samba4) escreve logs em syslog e/ou arquivos dependendo do `smb.conf`.

Exemplo no `smb.conf`:

```ini
[global]
logging = syslog@5 file
log file = /var/log/samba/samba.log
max log size = 10000
log level = 1 auth_audit:3 dsdb_audit:3
```

No servidor LOG, separar por categoria AD:

```conf
template(name="TmplADSamba" type="string"
         string="/var/log/central/ad/%HOSTNAME%/samba4.log")

if ($programname startswith "samba" or $syslogtag startswith "samba") then {
  action(type="omfile" dynaFile="TmplADSamba" createDirs="on")
  stop
}
```

Testes reais:
- Listar shares:
```bash
smbclient -L //10.0.0.3 -U "usuario%senha"
```
- Alterar/definir senha:
```bash
sudo samba-tool user setpassword usuario --newpassword='NovaSenha@123'
```

---

## 10. Logs do Antivírus (scans e scripts)

Além de logs nativos do `clamd`, os scripts de varredura podem enviar “resumos” via syslog (recomendado).

Exemplo (no servidor SMTP ou onde roda scan):
```bash
logger -t clamav-scan -p local6.info "SCAN OK: target=tmp infected=0 duration=12s"
```

No servidor LOG, separar por pasta `antivirus/` usando `local6` (como na seção 7.2).

---

## 11. Logs de NTP (Chrony)

O NTP interno roda no servidor LOG (10.0.0.2). Os demais servidores são clientes.

Para registrar offset e mudanças de fonte de forma clara, foi adotado um snapshot periódico com `chronyc`, enviado ao syslog via tag `ntp-snapshot`.

Script (`/usr/local/sbin/ntp-snapshot.sh`):

```bash
#!/bin/bash
{
  echo "=== tracking ==="
  chronyc -n tracking
  echo "=== sources ==="
  chronyc -n sources -v
} | logger -t ntp-snapshot -p local6.info
```

Cron (a cada 5 min):
```cron
*/5 * * * * /usr/local/sbin/ntp-snapshot.sh
```

No servidor LOG, separar logs do snapshot em pasta `ntp`:

```conf
template(name="TmplNTP" type="string"
         string="/var/log/central/ntp/%HOSTNAME%/ntp.log")

if ($programname == "ntp-snapshot") then {
  action(type="omfile" dynaFile="TmplNTP" createDirs="on")
  stop
}
```

Isso permite analisar:
- offset (tracking)
- fonte atual (`*` em sources)
- troca de fonte quando a preferida cai
- falhas quando `Reach` zera ou aparece `^?`

---

## 12. Testes e Validação

### 12.1 Teste geral (cliente → central)
Em qualquer servidor:
```bash
logger -p daemon.info "Teste de log para o servidor central"
```

### 12.2 Monitoramento em tempo real
No servidor LOG:
```bash
tail -f /var/log/central/*/syslog.log
tail -f /var/log/central/firewall/*/*.log
tail -f /var/log/central/ad/*/*.log
tail -f /var/log/central/antivirus/*/*.log
tail -f /var/log/central/ntp/*/*.log
```

---

## 13. Benefícios da Implementação

- Logs organizados por **host** e **serviço**
- Facilidade de troubleshooting
- Evidência clara para auditorias
- Base pronta para soluções de observabilidade (ELK/Graylog/Loki)
- Suporte a investigações (correlação de eventos entre firewall, AD e SMTP)

---

## 14. Considerações Finais

A implementação do syslog centralizado garante **observabilidade**, **rastreabilidade** e **controle operacional** de todo o ambiente, abrangendo Firewall, AD, SMTP, antivírus e NTP, com separação clara por host/serviço e suporte para auditorias e análise de incidentes.
