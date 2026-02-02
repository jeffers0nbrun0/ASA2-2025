# Configuração do Maildir e Postfix

## Passo 1: Configuração do Postfix

1. **Edite o arquivo de configuração do Postfix (`main.cf`)**

   O Postfix será configurado para usar **Maildir** como o backend de armazenamento de e-mails. Edite o arquivo `/etc/postfix/main.cf`:

   ```bash
   sudo nano /etc/postfix/main.cf
   ```

2. **Adicione ou modifique as seguintes linhas:**
   - **Definir `mydestination` para os domínios locais:**

     ```ini
     mydestination = $myhostname, localhost.localdomain, localhost, mailserver.empresanascimento.local, empresanascimento.local
     ```

   - **Usar Maildir como formato de armazenamento de e-mails:**

     ```ini
     home_mailbox = Maildir/
     ```

   - **Regras de restrição de destinatários (se necessário):**

     ```ini
     smtpd_recipient_restrictions = permit_mynetworks, reject_unauth_destination, check_policy_service inet:127.0.0.1:10031
     ```

3. **Configurar Domínios Virtuais (opcional)**

   Caso você use domínios virtuais, crie um arquivo `virtual` em `/etc/postfix/virtual`:

   ```bash
   sudo nano /etc/postfix/virtual
   ```

   Adicione entradas como estas:

   ```ini
   @empresanascimento.local usuario1@empresanascimento.local
   usuario2@empresanascimento.local   usuario2-maildir@empresanascimento.local
   ```

   Em seguida, gere o banco de dados do Postfix:

   ```bash
   sudo postmap /etc/postfix/virtual
   ```

4. **Reinicie o Postfix**

   Para aplicar as alterações, reinicie o Postfix:

   ```bash
   sudo systemctl restart postfix
   ```

## Passo 2: Configuração do Dovecot

1. **Instalar o Dovecot**

   Se ainda não estiver instalado, instale o Dovecot:

   ```bash
   sudo apt install dovecot-core dovecot-imapd dovecot-lmtpd
   ```

2. **Configurar o Dovecot para usar Maildir**

   Edite o arquivo de configuração do Dovecot (`/etc/dovecot/conf.d/10-mail.conf`):

   ```bash
   sudo nano /etc/dovecot/conf.d/10-mail.conf
   ```

   Modifique ou adicione a seguinte linha:

   ```ini
   mail_location = maildir:~/Maildir
   ```

3. **Habilitar e iniciar o Dovecot**

   Para que o Dovecot seja iniciado automaticamente e aceite as conexões IMAP, habilite e inicie o serviço:

   ```bash
   sudo systemctl enable dovecot
   sudo systemctl start dovecot
   ```

4. **Verificar o Status do Dovecot**

   Verifique se o Dovecot está em execução:

   ```bash
   sudo systemctl status dovecot
   ```

## Passo 3: Verificar Diretórios Maildir

1. **Criar Diretórios Maildir para Usuários**

   Se os diretórios Maildir não existirem para seus usuários, crie-os manualmente. Por exemplo:

   ```bash
   sudo mkdir -p /home/usuario1/Maildir
   sudo mkdir -p /home/usuario2/Maildir
   sudo chown -R usuario1:usuario1 /home/usuario1/Maildir
   sudo chown -R usuario2:usuario2 /home/usuario2/Maildir
   ```

2. **Verificar as permissões dos diretórios**

   Certifique-se de que os diretórios **Maildir** tenham as permissões corretas:

   ```bash
   sudo chmod -R 700 /home/usuario1/Maildir
   sudo chmod -R 700 /home/usuario2/Maildir
   ```

## Passo 4: Testar o Envio e Recebimento de E-mails

1. **Teste com Telnet:**

   Para testar o envio de e-mail via **SMTP** com **telnet**:

   ```bash
   telnet localhost 25
   HELO localhost
   MAIL FROM:<usuario1@empresanascimento.local>
   RCPT TO:<usuario2@empresanascimento.local>
   DATA
   Subject: Teste
   Este é um teste de envio de e-mail.
   .
   QUIT
   ```

2. **Verifique os Logs**

   Para verificar se houve algum erro ao enviar o e-mail, consulte os logs:

   ```bash
   sudo tail -f /var/log/mail.log
   ```

---

### Conclusão

- O **Postfix** foi configurado para usar **Maildir** e aceitar e-mails para domínios virtuais.
- O **Dovecot** foi configurado para entregar os e-mails usando **Maildir** via IMAP.
- As permissões dos diretórios **Maildir** foram corrigidas e os diretórios criados para os usuários.
