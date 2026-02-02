# Projeto Banco de Dados Corporativo (MariaDB) — dbempresanascimento

Este README documenta o que foi feito nesta etapa do projeto:

- Instalação do **MariaDB** no **Linux Mint 22.2**
- Criação do banco **dbempresanascimento**
- Criação de tabelas para as áreas **Financeiro, Comercial e TI**
- Popular (seed) de dados mínimos para teste
- Execução de um **CRUD completo** (ex.: Chamados do TI)

---

## 1) Instalação do MariaDB (Linux Mint 22.2)

```bash
sudo apt update
sudo apt install -y mariadb-server mariadb-client
sudo systemctl enable --now mariadb
sudo systemctl status mariadb --no-pager
```

---

## 2) Criar banco e usuário de acesso

Acesse o MariaDB como root do sistema (via socket):

```bash
sudo mariadb
```

Crie o banco e o usuário de aplicação:

> Ajuste a senha conforme necessário.

```sql
CREATE DATABASE IF NOT EXISTS dbempresanascimento
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

DROP USER IF EXISTS 'dbroot'@'localhost';
DROP USER IF EXISTS 'dbroot'@'127.0.0.1';

CREATE USER 'dbroot'@'localhost' IDENTIFIED BY 'dbroot';
CREATE USER 'dbroot'@'127.0.0.1' IDENTIFIED BY 'dbroot';

GRANT ALL PRIVILEGES ON dbempresanascimento.* TO 'dbroot'@'localhost';
GRANT ALL PRIVILEGES ON dbempresanascimento.* TO 'dbroot'@'127.0.0.1';

FLUSH PRIVILEGES;
EXIT;
```

Teste o acesso:

```bash
mariadb -u dbroot -p dbempresanascimento
```

---

## 3) Criar tabelas (Financeiro, Comercial e TI)

Conecte no banco:

```bash
mariadb -u dbroot -p dbempresanascimento
```

Execute o script SQL:

```sql
-- =========================
-- BASE CORPORATIVA
-- =========================

CREATE TABLE IF NOT EXISTS departamentos (
  id INT AUTO_INCREMENT PRIMARY KEY,
  nome VARCHAR(30) NOT NULL UNIQUE,
  criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS funcionarios (
  id INT AUTO_INCREMENT PRIMARY KEY,
  nome VARCHAR(120) NOT NULL,
  email VARCHAR(120) NOT NULL UNIQUE,
  departamento_id INT NOT NULL,
  ativo TINYINT(1) NOT NULL DEFAULT 1,
  criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (departamento_id) REFERENCES departamentos(id)
) ENGINE=InnoDB;

INSERT IGNORE INTO departamentos (nome)
VALUES ('financeiro'), ('comercial'), ('ti');

-- =========================
-- COMERCIAL
-- =========================

CREATE TABLE IF NOT EXISTS clientes (
  id INT AUTO_INCREMENT PRIMARY KEY,
  razao_social VARCHAR(150) NOT NULL,
  documento VARCHAR(20) NOT NULL UNIQUE,
  email VARCHAR(120),
  telefone VARCHAR(30),
  criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS pedidos (
  id INT AUTO_INCREMENT PRIMARY KEY,
  cliente_id INT NOT NULL,
  vendedor_id INT NOT NULL,
  descricao VARCHAR(255) NOT NULL,
  valor DECIMAL(10,2) NOT NULL,
  status ENUM('ABERTO','APROVADO','CANCELADO','FATURADO') NOT NULL DEFAULT 'ABERTO',
  criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (cliente_id) REFERENCES clientes(id),
  FOREIGN KEY (vendedor_id) REFERENCES funcionarios(id),
  INDEX (cliente_id),
  INDEX (vendedor_id),
  INDEX (status)
) ENGINE=InnoDB;

-- =========================
-- FINANCEIRO
-- =========================

CREATE TABLE IF NOT EXISTS faturas (
  id INT AUTO_INCREMENT PRIMARY KEY,
  pedido_id INT NOT NULL UNIQUE,
  emissor_id INT NOT NULL,
  vencimento DATE NOT NULL,
  valor DECIMAL(10,2) NOT NULL,
  status ENUM('EM_ABERTO','PAGO','VENCIDO','CANCELADO') NOT NULL DEFAULT 'EM_ABERTO',
  criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (pedido_id) REFERENCES pedidos(id),
  FOREIGN KEY (emissor_id) REFERENCES funcionarios(id),
  INDEX (vencimento),
  INDEX (status)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS pagamentos (
  id INT AUTO_INCREMENT PRIMARY KEY,
  fatura_id INT NOT NULL,
  recebido_por_id INT NOT NULL,
  data_pagamento DATETIME NOT NULL,
  valor_pago DECIMAL(10,2) NOT NULL,
  meio ENUM('PIX','BOLETO','CARTAO','DINHEIRO','TRANSFERENCIA') NOT NULL,
  FOREIGN KEY (fatura_id) REFERENCES faturas(id),
  FOREIGN KEY (recebido_por_id) REFERENCES funcionarios(id),
  INDEX (fatura_id),
  INDEX (data_pagamento)
) ENGINE=InnoDB;

-- =========================
-- TI
-- =========================

CREATE TABLE IF NOT EXISTS ativos_ti (
  id INT AUTO_INCREMENT PRIMARY KEY,
  patrimonio VARCHAR(50) NOT NULL UNIQUE,
  tipo ENUM('NOTEBOOK','DESKTOP','ROTEADOR','SWITCH','SERVIDOR','OUTRO') NOT NULL,
  modelo VARCHAR(120),
  responsavel_id INT,
  status ENUM('EM_USO','EM_ESTOQUE','MANUTENCAO','BAIXADO') NOT NULL DEFAULT 'EM_USO',
  criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (responsavel_id) REFERENCES funcionarios(id),
  INDEX (status)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS chamados_ti (
  id INT AUTO_INCREMENT PRIMARY KEY,
  solicitante_id INT NOT NULL,
  tecnico_id INT NULL,
  ativo_id INT NULL,
  titulo VARCHAR(150) NOT NULL,
  descricao TEXT NOT NULL,
  prioridade ENUM('BAIXA','MEDIA','ALTA','CRITICA') NOT NULL DEFAULT 'MEDIA',
  status ENUM('ABERTO','EM_ANDAMENTO','RESOLVIDO','CANCELADO') NOT NULL DEFAULT 'ABERTO',
  criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  atualizado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (solicitante_id) REFERENCES funcionarios(id),
  FOREIGN KEY (tecnico_id) REFERENCES funcionarios(id),
  FOREIGN KEY (ativo_id) REFERENCES ativos_ti(id),
  INDEX (status),
  INDEX (prioridade)
) ENGINE=InnoDB;
```

---

## 4) Popular dados mínimos (seed)

```sql
INSERT IGNORE INTO funcionarios (nome, email, departamento_id)
SELECT 'Ana Financeiro', 'ana.fin@empresa.com', id FROM departamentos WHERE nome='financeiro';

INSERT IGNORE INTO funcionarios (nome, email, departamento_id)
SELECT 'Bruno Comercial', 'bruno.com@empresa.com', id FROM departamentos WHERE nome='comercial';

INSERT IGNORE INTO funcionarios (nome, email, departamento_id)
SELECT 'Carla TI', 'carla.ti@empresa.com', id FROM departamentos WHERE nome='ti';

INSERT IGNORE INTO clientes (razao_social, documento, email, telefone)
VALUES ('ACME LTDA', '12345678000199', 'contato@acme.com', '+55 84 99999-9999');

INSERT IGNORE INTO ativos_ti (patrimonio, tipo, modelo, responsavel_id)
VALUES ('PAT-0001', 'NOTEBOOK', 'Dell Latitude',
        (SELECT id FROM funcionarios WHERE email='carla.ti@empresa.com'));
```

---

## 5) CRUD Completo (Chamados do TI)

### C) Create

```sql
INSERT INTO chamados_ti (solicitante_id, tecnico_id, ativo_id, titulo, descricao, prioridade)
VALUES (
  (SELECT id FROM funcionarios WHERE email='bruno.com@empresa.com'),
  (SELECT id FROM funcionarios WHERE email='carla.ti@empresa.com'),
  (SELECT id FROM ativos_ti WHERE patrimonio='PAT-0001'),
  'Sem acesso ao sistema',
  'Ao abrir o sistema de vendas, apresenta erro de autenticação.',
  'ALTA'
);
```

### R) Read

```sql
SELECT
  c.id,
  c.titulo,
  c.prioridade,
  c.status,
  c.criado_em,
  fsol.nome AS solicitante,
  ftec.nome AS tecnico,
  a.patrimonio AS ativo
FROM chamados_ti c
JOIN funcionarios fsol ON fsol.id = c.solicitante_id
LEFT JOIN funcionarios ftec ON ftec.id = c.tecnico_id
LEFT JOIN ativos_ti a ON a.id = c.ativo_id
ORDER BY c.id DESC;
```

### U) Update

```sql
UPDATE chamados_ti
SET status='EM_ANDAMENTO'
WHERE id = (SELECT MAX(id) FROM chamados_ti);

UPDATE chamados_ti
SET status='RESOLVIDO'
WHERE id = (SELECT MAX(id) FROM chamados_ti);
```

### D) Delete

```sql
DELETE FROM chamados_ti
WHERE id = (SELECT MAX(id) FROM chamados_ti);
```

---

## 6) Verificações rápidas (para evidência no relatório)

```sql
SHOW TABLES;
SELECT COUNT(*) AS total_clientes FROM clientes;
SELECT COUNT(*) AS total_pedidos FROM pedidos;
SELECT COUNT(*) AS total_chamados FROM chamados_ti;
```

---

- Implementar 2 métodos de backup (ex.: `mysqldump` + backup físico/snapshot)
- Restaurar ambos e comprovar integridade/consistência

- Banco: `dbempresanascimento`
- Usuário (aplicação): `dbroot`
- Diretório de backups: `/srv/backups/mariadb`

---

## 0) Preparação de diretórios

```bash
sudo mkdir -p /srv/backups/mariadb/{dump,physical,checks}
sudo chown -R $USER:$USER /srv/backups/mariadb
```

---

## 1) Evidência de integridade (antes e depois)

### 1.1) Gerar “integridade antes”

```bash
mariadb -u dbroot -p -D dbempresanascimento -e "
SELECT 'departamentos' AS tabela, COUNT(*) AS qtd FROM departamentos
UNION ALL SELECT 'funcionarios', COUNT(*) FROM funcionarios
UNION ALL SELECT 'clientes', COUNT(*) FROM clientes
UNION ALL SELECT 'pedidos', COUNT(*) FROM pedidos
UNION ALL SELECT 'faturas', COUNT(*) FROM faturas
UNION ALL SELECT 'pagamentos', COUNT(*) FROM pagamentos
UNION ALL SELECT 'ativos_ti', COUNT(*) FROM ativos_ti
UNION ALL SELECT 'chamados_ti', COUNT(*) FROM chamados_ti;
" | tee /srv/backups/mariadb/checks/integridade_antes.txt
```

### 1.2) Gerar “integridade depois” (após cada restauração) + comparar

```bash
mariadb -u dbroot -p -D dbempresanascimento -e "
SELECT 'departamentos' AS tabela, COUNT(*) AS qtd FROM departamentos
UNION ALL SELECT 'funcionarios', COUNT(*) FROM funcionarios
UNION ALL SELECT 'clientes', COUNT(*) FROM clientes
UNION ALL SELECT 'pedidos', COUNT(*) FROM pedidos
UNION ALL SELECT 'faturas', COUNT(*) FROM faturas
UNION ALL SELECT 'pagamentos', COUNT(*) FROM pagamentos
UNION ALL SELECT 'ativos_ti', COUNT(*) FROM ativos_ti
UNION ALL SELECT 'chamados_ti', COUNT(*) FROM chamados_ti;
" | tee /srv/backups/mariadb/checks/integridade_depois.txt

diff -u /srv/backups/mariadb/checks/integridade_antes.txt /srv/backups/mariadb/checks/integridade_depois.txt
```

Se o `diff` não mostrar diferenças, os dados restaurados estão consistentes com o estado anterior ao backup.

---

## 2) Método 1 — Backup Lógico (mysqldump)

### 2.1) Backup (dump SQL)

```bash
DATA="$(date +%F_%H%M%S)"

mysqldump -u dbroot -p   --single-transaction --routines --events --triggers   --databases dbempresanascimento   > /srv/backups/mariadb/dump/dbempresanascimento_${DATA}.sql

sha256sum /srv/backups/mariadb/dump/dbempresanascimento_${DATA}.sql   > /srv/backups/mariadb/dump/dbempresanascimento_${DATA}.sql.sha256
```

### 2.2) Restauração do dump

> **ATENÇÃO:** substitui o banco (use para teste/relatório).

```bash
sudo mariadb -e "DROP DATABASE IF EXISTS dbempresanascimento;
CREATE DATABASE dbempresanascimento CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

mariadb -u dbroot -p < /srv/backups/mariadb/dump/dbempresanascimento_${DATA}.sql
```

### 2.3) Validar integridade

Rode a seção **1.2** e confira o `diff`.

---

## 3) Método 2 — Backup Físico (mariadb-backup)

### 3.1) Instalar ferramenta

```bash
sudo apt update
sudo apt install -y mariadb-backup
```

### 3.2) Criar usuário de backup (apenas para o backup físico)

```bash
sudo mariadb -e "
DROP USER IF EXISTS 'mariabackup'@'localhost';
CREATE USER 'mariabackup'@'localhost' IDENTIFIED BY 'mariabackup';
GRANT RELOAD, PROCESS, LOCK TABLES, BINLOG MONITOR ON *.* TO 'mariabackup'@'localhost';
FLUSH PRIVILEGES;
SHOW GRANTS FOR 'mariabackup'@'localhost';
"
```

Teste rápido:

```bash
mariadb -u mariabackup -p -e "SELECT 1;"
```

### 3.3) Backup físico (online) + prepare

```bash
DATA="$(date +%F_%H%M%S)"
TARGET="/srv/backups/mariadb/physical/full_${DATA}"

sudo mariadb-backup --backup   --target-dir="$TARGET"   --user=mariabackup --password='mariabackup'

sudo mariadb-backup --prepare --target-dir="$TARGET"

sudo ls -lh "$TARGET" | head
```

### 3.4) Restauração física (copy-back)

> **ATENÇÃO:** este procedimento substitui o `datadir`. Faça somente para teste/relatório.  
> Antes, opcionalmente rode a seção **1.1** para salvar as contagens “antes”.

1. Descobrir o `datadir` (normalmente `/var/lib/mysql/`):

```bash
sudo mariadb -Nse "SELECT @@datadir;"
```

2. Parar serviço e salvar o datadir atual:

```bash
sudo systemctl stop mariadb

# ajuste se o seu datadir for outro
sudo mv /var/lib/mysql /var/lib/mysql.bak_$(date +%F_%H%M%S)
sudo mkdir -p /var/lib/mysql
sudo chown -R mysql:mysql /var/lib/mysql
```

3. Copy-back do backup preparado:

```bash
sudo mariadb-backup --copy-back --target-dir="$TARGET"
sudo chown -R mysql:mysql /var/lib/mysql
```

4. Subir serviço:

```bash
sudo systemctl start mariadb
sudo systemctl status mariadb --no-pager
```

### 3.5) Validar integridade

Rode a seção **1.2** e confira o `diff`.

---

## Evidências recomendadas para anexar no relatório

- Listagem dos backups:
  ```bash
  ls -lh /srv/backups/mariadb/dump/
  ls -lh /srv/backups/mariadb/physical/
  ```
  ```python
  root@BANCO:/home/serverif# ls -lh /srv/backups/mariadb/dump/
  ls -lh /srv/backups/mariadb/physical/
  total 12K
  -rw-r--r-- 1 root root 12K jan 25 11:43 dbempresanascimento_.sql
  total 8,0K
  drwx------ 7 root root 4,0K jan 25 11:49 full_2026-01-25_114919
  drwx------ 7 root root 4,0K jan 25 11:54 full_2026-01-25_115335
  root@BANCO:/home/serverif#
  ```

````


- Validação do dump:
  ```bash
  sha256sum -c /srv/backups/mariadb/dump/dbempresanascimento_*.sql.sha256
````

- Prova de integridade:
  ```bash
  diff -u /srv/backups/mariadb/checks/integridade_antes.txt /srv/backups/mariadb/checks/integridade_depois.txt
  ```
