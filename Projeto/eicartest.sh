# Criar arquivo de teste EICAR
cat > criar_testes_virus.sh << 'EOF'
#!/bin/bash
echo "=== CRIAÇÃO DE ARQUIVOS DE TESTE EICAR ==="

# EICAR padrão (texto)
echo "Criando EICAR padrão..."
echo 'X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*' > /tmp/eicar.com
echo "EICAR padrão criado: /tmp/eicar.com"

# EICAR em texto (para testar em anexo de email)
echo "Criando EICAR para email..."
cat > /tmp/eicar.txt << EICAR
X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*
Este é o arquivo de teste EICAR padrão.
Não é um vírus real, apenas uma assinatura de teste.
EICAR

# EICAR comprimido (testar varredura em arquivos compactados)
echo "Criando EICAR compactado..."
zip -j /tmp/eicar.zip /tmp/eicar.com 2>/dev/null
tar -czf /tmp/eicar.tar.gz /tmp/eicar.com 2>/dev/null

echo "Arquivos de teste criados:"
ls -la /tmp/eicar*

echo ""
echo "TESTANDO DETECÇÃO:"
echo "=================="

# Testar com clamscan
echo "1. Teste direto com clamscan:"
clamscan /tmp/eicar.com
echo ""

# Testar com clamd
echo "2. Teste via clamd (daemon):"
echo "/tmp/eicar.com" | nc localhost 3310
echo ""

# Testar arquivo compactado
echo "3. Teste arquivo ZIP:"
clamscan /tmp/eicar.zip
echo ""

echo "=== TESTES CONCLUÍDOS ==="
EOF

chmod +x criar_testes_virus.sh
./criar_testes_virus.sh