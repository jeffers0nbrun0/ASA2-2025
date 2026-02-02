# Script completo para configurar distribuição
cat > setup-log-distribution.sh << 'EOF'
#!/bin/bash
echo "=============================================="
echo "CONFIGURANDO DISTRIBUIÇÃO DE LOGS"
echo "=============================================="

# 1. Parar rsyslog temporariamente
echo "1. Parando rsyslog..."
sudo systemctl stop rsyslog

# 2. Criar estrutura de diretórios
echo "2. Criando estrutura..."
sudo mkdir -p /var/log/{smtp,firewall,database,ntp,ad}
sudo mkdir -p /var/log/smtp

# 3. Ajustar permissões
echo "3. Ajustando permissões..."
sudo chown -R syslog:adm /var/log/{smtp,firewall,database,ntp,ad}
sudo chmod 750 /var/log/{smtp,firewall,database,ntp,ad}

# 4. Criar arquivos de log
echo "4. Criando arquivos..."
for service in smtp; do
    case $service in
        smtp)
            files="delivered rejected spam virus general"
            ;;
        firewall)
            files="accepted blocked rejected general"
            ;;
        database)
            files="queries errors performance general"
            ;;
        ntp)
            files="synchronization peers drift errors general"
            ;;
        ad)
            files="auth-success auth-failed password-changes group-changes general"
            ;;
    esac
    
    for file in $files; do
        sudo touch /var/log/$service/$file.log 2>/dev/null
        sudo chown syslog:adm /var/log/$service/$file.log 2>/dev/null
        sudo chmod 640 /var/log/$service/$file.log 2>/dev/null
    done
done

# 5. Configurar regras de distribuição
echo "5. Criando regras de distribuição..."

# Regras para Email
sudo tee /etc/rsyslog.d/10-email-distribution.conf > /dev/null << 'CONFIGEOF'
# Distribuição de logs de Email

if (\$programname == 'postfix/smtp' and (\$msg contains 'status=sent' or \$msg contains 'delivered')) then {
    /var/log/smtp/delivered.log
    stop
}

if (\$programname == 'postfix/smtpd' and (\$msg contains 'reject' or \$msg contains '554' or \$msg contains '550')) then {
    /var/log/smtp/rejected.log
    stop
}

if ((\$programname == 'spamassassin' or \$msg contains 'SPAM') and \$msg contains 'SPAM') then {
    /var/log/smtp/spam.log
    stop
}

if ((\$programname == 'amavis' or \$msg contains 'virus') and \$msg contains 'virus') then {
    /var/log/smtp/virus.log
    stop
}

if (\$programname == 'postfix' or \$programname == 'dovecot' or \$syslogtag contains 'postfix' or \$syslogtag contains 'dovecot') then {
    /var/log/smtp/general.log
    stop
}
CONFIGEOF

# 6. Configuração padrão para logs não classificados
echo "6. Configuração padrão..."
sudo tee /etc/rsyslog.d/99-default.conf > /dev/null << 'CONFIGEOF'
# Logs não classificados vão para arquivo único
*.* /var/log/uncategorized.log
CONFIGEOF

sudo touch /var/log/uncategorized.log
sudo chown syslog:adm /var/log/uncategorized.log

# 7. Iniciar rsyslog
echo "7. Iniciando rsyslog..."
sudo systemctl start rsyslog

# 8. Testar
echo "8. Testando configuração..."
echo "Enviando logs de teste..."

test_logs=(
    "postfix/smtp: TESTE-DELIVERED: status=sent (delivered)"
    "postfix/smtpd: TESTE-REJECTED: NOQUEUE: reject: 554 5.7.1"
    "spamassassin: TESTE-SPAM: SPAM: Score: 9.0"
    "amavis: TESTE-VIRUS: INFECTED: virus found"
    "postfix/smtpd: TESTE-GENERAL: connect from client"
)

for log in "${test_logs[@]}"; do
    logger -n 127.0.0.1 -P 514 -t "${log%%:*}" "${log#*: }"
    sleep 0.5
done

# 9. Verificar resultados
echo ""
echo "9. Verificando distribuição:"
echo "---------------------------"
for file in delivered rejected spam virus general; do
    echo -n "$file.log: "
    if sudo grep -q "TESTE-" /var/log/smtp/$file.log 2>/dev/null; then
        echo "✓ OK (recebeu log)"
    else
        echo "✗ Vazio"
    fi
done

echo ""
echo "uncategorized.log:"
sudo tail -1 /var/log/uncategorized.log 2>/dev/null | grep -o "TESTE-.*" || echo "Vazio"

echo ""
echo "=============================================="
echo "CONFIGURAÇÃO CONCLUÍDA!"
echo "=============================================="
EOF

# Executar script
chmod +x setup-log-distribution.sh
sudo ./setup-log-distribution.sh