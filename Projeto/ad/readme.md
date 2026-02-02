# Servidor Samba 4 com Active Directory, ACLs e Autenticação Centralizada

Este README descreve **como instalar e configurar** um servidor **Samba 4 como Controlador de Domínio (AD DC)**, criar **OUs, grupos, usuários**, organizar compartilhamentos por **departamento** e aplicar **ACLs** para controle avançado de permissões.

> Ambiente alvo: Debian/Ubuntu/Linux Mint Server (Mint 22.x / Ubuntu 24.04-base)  
> Samba: 4.x (serviço `samba-ad-dc`)

---

## 1. Visão Geral
Este projeto implementa um servidor **Samba 4 atuando como Controlador de Domínio Active Directory (AD DC)**, com autenticação centralizada (LDAP/Kerberos), DNS interno e permissões avançadas via ACLs, organizando usuários e compartilhamentos por departamento.

---

## 2. Domínio e Serviços
- Domínio (Realm Kerberos): `ADSERVER.LOCAL`
- NetBIOS (Domain): `ADSERVER`
- Hostname do DC: `dc-adserver`
- Serviço principal: `samba-ad-dc` (Samba 4 AD DC)
- DNS: `SAMBA_INTERNAL`
- Kerberos: Integrado ao Active Directory

---

## 3. Pré-requisitos

### 3.1 IP fixo (recomendado)
Defina um IP fixo para o controlador de domínio. Exemplo:
- IP: `10.0.0.2/24`
- Gateway: `10.0.0.1`
- DNS: `127.0.0.1` (após o Samba subir)

> Ajuste os valores conforme sua rede.

### 3.2 Hostname e /etc/hosts (obrigatório)
```bash
sudo hostnamectl set-hostname dc-adserver
hostnamectl
```

Edite o `/etc/hosts` (ajuste o IP do seu DC):
```bash
sudo nano /etc/hosts
```

Exemplo:
```text
127.0.0.1   localhost
10.0.0.2    dc-adserver.adserver.local dc-adserver
```

---

## 4. Instalação dos pacotes

```bash
sudo apt update
sudo apt install -y samba krb5-user krb5-config winbind libnss-winbind libpam-winbind dnsutils acl
```

Durante a instalação do Kerberos (se perguntar):
- Default realm: `ADSERVER.LOCAL`
- KDC/Admin server: `dc-adserver.adserver.local`

> Mesmo que você ainda não vá integrar login Linux via AD, o Kerberos será usado nos testes.

---

## 5. Preparação antes do provisionamento

Pare/disable serviços que conflitam com AD DC:
```bash
sudo systemctl stop smbd nmbd winbind systemd-resolved 2>/dev/null || true
sudo systemctl disable smbd nmbd winbind 2>/dev/null || true
```

Faça backup do smb.conf (se existir):
```bash
sudo mv /etc/samba/smb.conf /etc/samba/smb.conf.bak 2>/dev/null || true
```

Antes de provisionar, garanta que o servidor está resolvendo o próprio nome.  
(Além do `/etc/hosts`, é comum usar DNS local depois. No provisionamento, o `/etc/hosts` é o essencial.)

---

## 6. Provisionar o domínio (Samba AD DC)

Execute o provisionamento interativo:
```bash
sudo samba-tool domain provision --use-rfc2307 --interactive
```

Respostas típicas:
- Realm: `ADSERVER.LOCAL`
- Domain (NetBIOS): `ADSERVER`
- Server Role: `dc`
- DNS backend: `SAMBA_INTERNAL`
- DNS forwarder: `8.8.8.8` (ou DNS upstream da sua rede)
- Senha do `Administrator`: defina uma forte

---

## 7. Kerberos (krb5.conf) e teste

Após provisionar, copie o arquivo gerado:
```bash
sudo cp /var/lib/samba/private/krb5.conf /etc/krb5.conf
```

Teste:
```bash
kinit administrator@ADSERVER.LOCAL
klist
```

---

## 8. Subir o serviço do AD DC

```bash
sudo systemctl enable --now samba-ad-dc
sudo systemctl status samba-ad-dc --no-pager
```

Testes DNS internos (no próprio servidor):
```bash
host -t A dc-adserver.adserver.local 127.0.0.1
host -t SRV _kerberos._udp.adserver.local 127.0.0.1
```

---

## 9. Estrutura de Diretórios Corporativos

```bash
sudo mkdir -p /srv/empresa/{ti,financeiro,comercial}
```

Estrutura esperada:
```bash
/srv/empresa/
├── ti
├── financeiro
└── comercial
```

---

## 10. Unidades Organizacionais (OU)

Criar OUs:
```bash
sudo samba-tool ou create "OU=ti,DC=adserver,DC=local"
sudo samba-tool ou create "OU=financeiro,DC=adserver,DC=local"
sudo samba-tool ou create "OU=comercial,DC=adserver,DC=local"
```

Verificação:
```bash
sudo samba-tool ou list
```

---

## 11. Grupos do Domínio

Criar grupos:
```bash
sudo samba-tool group add ti
sudo samba-tool group add financeiro
sudo samba-tool group add comercial
```

| Grupo        | Departamento |
|-------------|--------------|
| ti          | TI           |
| financeiro  | Financeiro   |
| comercial   | Comercial    |

---

## 12. Usuários Criados

### 12.1 TI
- usuarioTI1
- usuarioTI2
- usuarioTI3

Exemplo:
```bash
sudo samba-tool user add usuarioTI1 \
  --given-name="Usuario TI 1" \
  --surname="Departamento TI" \
  --password="ti@2026" \
  --userou="OU=ti"
```

### 12.2 Financeiro
- usuarioFinanceiro1
- usuarioFinanceiro2
- usuarioFinanceiro3

### 12.3 Comercial
- usuarioComercial1
- usuarioComercial2
- usuarioComercial3

> Crie os demais usuários repetindo o padrão do comando acima, mudando `--userou`.

---

## 13. Associação Usuários x Grupos

```bash
sudo samba-tool group addmembers "ti" "usuarioTI1 usuarioTI2 usuarioTI3"
sudo samba-tool group addmembers "financeiro" "usuarioFinanceiro1 usuarioFinanceiro2 usuarioFinanceiro3"
sudo samba-tool group addmembers "comercial" "usuarioComercial1 usuarioComercial2 usuarioComercial3"
```

---

## 14. Compartilhamentos Samba (smb.conf)

Edite:
```bash
sudo nano /etc/samba/smb.conf
```

No final, adicione:

```ini
[TI]
path = /srv/empresa/ti
valid users = @ti
read only = no
browseable = yes

[Financeiro]
path = /srv/empresa/financeiro
valid users = @financeiro
read only = no
browseable = yes

[Comercial]
path = /srv/empresa/comercial
valid users = @comercial
read only = no
browseable = yes
```

Validar e reiniciar:
```bash
testparm
sudo systemctl restart samba-ad-dc
```

---

## 15. ACLs – Controle Avançado de Permissões

Instalar suporte (se ainda não estiver):
```bash
sudo apt install -y acl
```

### 15.1 Modelo recomendado (limpo) por diretório
Zera ACLs herdadas e aplica apenas o grupo do departamento com `rwx`:

**TI**
```bash
sudo setfacl -b /srv/empresa/ti
sudo setfacl -m g:ti:rwx /srv/empresa/ti
sudo setfacl -m mask::rwx /srv/empresa/ti
```

**Financeiro**
```bash
sudo setfacl -b /srv/empresa/financeiro
sudo setfacl -m g:financeiro:rwx /srv/empresa/financeiro
sudo setfacl -m mask::rwx /srv/empresa/financeiro
```

**Comercial**
```bash
sudo setfacl -b /srv/empresa/comercial
sudo setfacl -m g:comercial:rwx /srv/empresa/comercial
sudo setfacl -m mask::rwx /srv/empresa/comercial
```

Verificar ACL:
```bash
getfacl /srv/empresa/ti
getfacl /srv/empresa/financeiro
getfacl /srv/empresa/comercial
```

---

## 16. Conflito Real de Permissões (máscara ACL)

### Problema
Usuário/grupo com ACL explícita não conseguia escrever no diretório.

### Motivo técnico
A **máscara ACL** limita as permissões efetivas. Mesmo que a entrada do grupo esteja `rwx`, se a máscara estiver `r-x`, o efetivo vira `r-x`.

### Solução
Ajuste da máscara:
```bash
sudo setfacl -m mask::rwx /srv/empresa/ti
```

---

## 17. Diretórios Home de Usuários do Domínio (opcional)

Exemplo manual:
```bash
sudo mkdir -p /home/ADSERVER/usuarioTI1
sudo chown usuarioTI1:usuarioTI1 /home/ADSERVER/usuarioTI1
```

---

## 18. Testes Realizados

### 18.1 Kerberos
```bash
kinit usuarioTI1@ADSERVER.LOCAL
klist
```

### 18.2 Acesso ao compartilhamento via smbclient (local)
```bash
smbclient //localhost/TI -U 'ADSERVER\\usuarioTI1' -c 'ls'
```

### 18.3 Escrita no diretório (no servidor)
```bash
sudo -u usuarioTI1 touch /srv/empresa/ti/teste.txt
ls -l /srv/empresa/ti
```

---

## 19. Checklist de evidências para o relatório

```bash
sudo samba-tool domain info 127.0.0.1
sudo samba-tool ou list
sudo samba-tool group list | egrep "ti|financeiro|comercial"
sudo samba-tool user list | head
testparm -s | egrep "^\[TI\]|\[Financeiro\]|\[Comercial\]"
getfacl /srv/empresa/ti
```

---

## 20. Conclusão

O ambiente demonstra um cenário corporativo funcional com:
- Samba 4 AD DC
- LDAP/Kerberos e DNS interno
- OUs, grupos e usuários por departamento
- Compartilhamentos restritos por grupo
- ACLs avançadas e resolução de conflito real de máscara
