#!/bin/bash
# Script de varredura diária do ClamAV
LOG_FILE="/var/log/clamav/daily_scan_$(date +%Y%m%d).log"
SCAN_DIRS="/home /var/www /tmp /usr /etc /opt"
QUARANTINE_DIR="/var/quarantine"

# Criar diretório de quarentena
mkdir -p "$QUARANTINE_DIR"
chown clamav:clamav "$QUARANTINE_DIR"

echo "=== VARREDURA DIÁRIA CLAMAV - $(date) ===" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Atualizar assinaturas
echo "1. Atualizando assinaturas..." | tee -a "$LOG_FILE"
freshclam --verbose 2>&1 | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Varredura completa dos diretórios críticos
echo "2. Iniciando varredura..." | tee -a "$LOG_FILE"
for dir in $SCAN_DIRS; do
    if [ -d "$dir" ]; then
        echo "   Varrendo: $dir" | tee -a "$LOG_FILE"
        clamscan -r -i --move="$QUARANTINE_DIR" --log="$LOG_FILE" "$dir" 2>&1 | tail -5 | tee -a "$LOG_FILE"
        echo "" | tee -a "$LOG_FILE"
    fi
done

# Resumo
echo "3. RESUMO DA VARREDURA:" | tee -a "$LOG_FILE"
INFECTED=$(grep -c "FOUND" "$LOG_FILE" 2>/dev/null || echo "0")
SCANNED=$(grep "Scanned files" "$LOG_FILE" | tail -1 | awk '{print $3}' || echo "0")

echo "   Arquivos escaneados: $SCANNED" | tee -a "$LOG_FILE"
echo "   Arquivos infectados: $INFECTED" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Se encontrou vírus, enviar alerta
if [ "$INFECTED" -gt 0 ]; then
    echo "ALERTA: $INFECTED arquivo(s) infectado(s) encontrado(s)!" | tee -a "$LOG_FILE"
    echo "   Em quarentena: $QUARANTINE_DIR" | tee -a "$LOG_FILE"
    
    # Enviar email de alerta (opcional)
    echo "Enviando alerta por email..." | tee -a "$LOG_FILE"
    echo "Alerta: $INFECTED vírus encontrados no servidor $(hostname)" | \
        mail -s "ALERTA ClamAV - $(date)" root@localhost
fi

echo "=== VARREDURA CONCLUÍDA ===" | tee -a "$LOG_FILE"