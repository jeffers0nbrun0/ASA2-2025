# Postfix + Maildir + DNS local + SpamAssassin + ClamAV (Milter)

Este README documenta a instalação e configuração de um servidor **Postfix** usando **Maildir** como backend de entrega local, com apoio de **DNS local** para o domínio do laboratório, integração com **SpamAssassin** e **ClamAV** via **milter**.

> Ambiente pensado para lab (domínio `.local`), mas o fluxo vale igual em produção (com DNS real).

---

## 1) Instalação dos pacotes

### 1.1 Postfix + utilitários
```bash
sudo apt update
sudo apt install -y postfix mailutils
```

Durante a instalação do Postfix:
- Tipo: Internet Site
- Hostname: mailserver.empresanascimento.local

### 1.2 SpamAssassin
```bash
sudo apt install -y spamassassin spamc
sudo systemctl enable --now spamassassin
```

### 1.3 ClamAV
```bash
sudo apt install -y clamav clamav-daemon clamav-milter clamav-freshclam
sudo systemctl enable --now clamav-freshclam clamav-daemon clamav-milter
sudo freshclam
```

---

## 2) DNS local

Edite `/etc/hosts`:
```
127.0.0.1   localhost
127.0.1.1   mailserver.empresanascimento.local mailserver
```

---

## 3) Postfix com Maildir

Em `/etc/postfix/main.cf`:
```conf
myhostname = mailserver.empresanascimento.local
mydomain = empresanascimento.local
myorigin = $mydomain
mydestination = $myhostname, localhost.$mydomain, localhost
home_mailbox = Maildir/
```

Criar Maildir:
```bash
sudo -u usuario2 mkdir -p /home/usuario2/Maildir/{cur,new,tmp}
```

---

## 4) SpamAssassin

Em `/etc/postfix/master.cf`:
```conf
spamassassin unix  - n n - - pipe
  user=spamd argv=/usr/bin/spamc -f -e /usr/sbin/sendmail -oi -f ${sender} ${recipient}
```

No serviço smtp:
```conf
-o content_filter=spamassassin
```

---

## 5) ClamAV + Milter

### 5.1 Testar clamd
```bash
echo PING | nc -U /var/run/clamav/clamd.ctl
```

### 5.2 clamav-milter.conf
```conf
MilterSocket /var/run/clamav/clamav-milter.ctl
ClamdSocket unix:/var/run/clamav/clamd.ctl
MilterSocketGroup clamav
MilterSocketMode 666
FixStaleSocket yes
```

### 5.3 Postfix
```conf
smtpd_milters = unix:/var/run/clamav/clamav-milter.ctl
non_smtpd_milters = unix:/var/run/clamav/clamav-milter.ctl
milter_default_action = accept
milter_protocol = 6
```

---

## 6) Envio via nc

```bash
cat <<'EOF' | nc 127.0.0.1 25
EHLO localhost
MAIL FROM:<usuario1@empresanascimento.local>
RCPT TO:<usuario2@localhost>
DATA
Subject: Teste NC

Mensagem simples
.
QUIT
EOF
```

---

## 7) Teste EICAR

```bash
cat <<'EOF' | nc 127.0.0.1 25
EHLO localhost
MAIL FROM:<usuario1@empresanascimento.local>
RCPT TO:<usuario2@localhost>
DATA
Subject: Teste EICAR

X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*
.
QUIT
EOF
```

---

## 8) Logs

```bash
tail -f /var/log/mail.log
journalctl -u clamav-milter
journalctl -u clamav-daemon
```

---
