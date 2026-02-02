# Diagrama de Arquitetura (Rede Interna)

Rede interna usada: **enp0s8 – 10.0.0.0/24**  
(Endereçamento externo/publico foi ignorado por decisão do projeto)

## Nós

- **SRV1 (10.0.0.3)** — LDAP / Samba / Active Directory
- **SRV2 (10.0.0.1)** — Firewall / Netfilter (Gateway)
- **SRV3 (10.0.0.5)** — SMTP + Antivírus
- **SRV4 (10.0.0.4)** — Banco de Dados
- **SRV5 (10.0.0.2)** — Logs e NTP

## Diagrama (Mermaid)

```mermaid
flowchart LR

subgraph CLIENTES["Clientes"]
direction TB
PAMNSS["Linux PAM NSS"]
SMBCLIENT["Cliente SMB"]
end

subgraph LAN["LAN 10.0.0.0/24"]
direction LR
FW["SRV2 Firewall<br/>10.0.0.1/24"]
LOGS["SRV5 Logs NTP<br/>10.0.0.2/24"]
ADDC["SRV1 Samba AD DC<br/>10.0.0.3/24"]
DB["SRV4 MariaDB<br/>10.0.0.4/24"]
SMTP["SRV3 SMTP AV<br/>10.0.0.5/24"]
end

INET[(Internet)]

ADDC <--> DB
SMTP <--> DB

PAMNSS -->|SSH| ADDC
SMBCLIENT -->|SMB| ADDC
LOGS -->|LDAP opcional| ADDC

FW -->|Syslog| LOGS
ADDC -->|Syslog| LOGS
DB -->|Syslog| LOGS
SMTP -->|Syslog| LOGS

LOGS -->|NTP| FW
LOGS -->|NTP| ADDC
LOGS -->|NTP| DB
LOGS -->|NTP| SMTP

FW -->|NAT Forward| INET
```
