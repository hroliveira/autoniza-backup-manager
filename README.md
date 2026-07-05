# 🔄 Autoniza Backup Manager (v2.0)

**Plataforma Completa de Backup e Restore para servidores Linux, Docker e Coolify.** 

O Autoniza Backup Manager centraliza toda a lógica de segurança em uma CLI moderna e poderosa chamada `abm`, automatizando dumps de bancos de dados (PostgreSQL, MySQL, Redis), pastas do sistema e volumes Docker, armazenando tudo criptografado no S3/MinIO via Restic.

---

## ✨ Funcionalidades

- 💻 **CLI Unificada (`abm`):** Uma única interface intuitiva para interagir com backups, restaurações, status, agendamento e diagnósticos.
- 📦 **Backup de Bancos de Dados:** PostgreSQL (`pg_dump`), MySQL/MariaDB (`mysqldump`) e Redis (snapshots `.rdb`).
- 🗂️ **Backup de Pastas do Sistema:** Diretórios arbitrários (como `/data/coolify`).
- 🐳 **Docker Volumes:** Backup e restore integrados com containers ativos.
- 🔐 **Criptografia Restic:** Criptografia de ponta a ponta nativa do Restic.
- ☁️ **Destino S3/MinIO:** Armazenamento seguro em qualquer nuvem compatível com S3.
- 📅 **Retenção Inteligente:** Aplicação de políticas diárias, semanais e mensais.
- 🩺 **Doctor Checks (`abm doctor`):** Bateria de 20 testes de integridade e dependências com cálculo de **Health Score**.
- 📊 **Relatórios Locais & Telemetria:** Arquivos txt/html gerados automaticamente e envio de Webhooks com payloads JSON detalhados.
- 🔌 **Hooks Avançados:** Scripts customizados executados pré/pós backup e pré/pós restore.
- ⏰ **Gerenciador Cron Integrado:** Configure agendamentos automáticos em segundos.

---

## 🚀 Instalação Rápida

Clone o repositório e execute o instalador (como root para habilitar a CLI globalmente):

```bash
git clone https://github.com/hroliveira/autoniza-backup-manager.git
cd autoniza-backup-manager
sudo bash install.sh
```

A instalação irá configurar todos os arquivos em `/opt/autoniza-backup` e linkar a CLI globalmente em `/usr/local/bin/abm`.

---

## ⚙️ Configuração

### 1. Credenciais S3/MinIO
Edite `/opt/autoniza-backup/config/config.env`:
```env
RESTIC_REPOSITORY="s3:https://api-minio.seudominio.com/coolifybkp"
AWS_ACCESS_KEY_ID="sua_access_key"
AWS_SECRET_ACCESS_KEY="sua_secret_key"
RESTIC_PASSWORD="senha_forte_para_criptografia"
```

### 2. Configurações de Escopo e Retenção
Edite `/opt/autoniza-backup/config/backup.yaml` ou use `abm config`:
```yaml
server:
  name: coolify-prod
  environment: production

retention:
  daily: 7
  weekly: 4
  monthly: 12

folders:
  - /data/coolify

postgres:
  - name: coolify-db
    container: coolify-db
    database: coolify
    user: coolify

redis:
  - name: coolify-redis
    container: coolify-redis

notifications:
  webhook_url: "https://seu-n8n.dominio.com/webhook/backup"
```

---

## ▶️ Uso da CLI `abm`

O Autoniza Backup Manager fornece uma CLI moderna e interativa:

### 1. Diagnósticos do Sistema
Rode o doctor para verificar dependências, conexões, credenciais e permissões:
```bash
abm doctor
```

### 2. Executar Backup
Inicie um processo completo de backup imediatamente:
```bash
abm backup
```

### 3. Restauração (Modo Interativo)
Inicie o menu interativo para escolher o snapshot e o que deseja restaurar:
```bash
abm restore
```

### 4. Extração Segura / Simulação (Dry-Run)
Extraia um snapshot para revisão ou faça uma simulação seca:
```bash
abm restore --snapshot <snapshot-id>
abm restore --snapshot <snapshot-id> --dry-run
```

Para escrever em containers/caminhos originais, use `--apply` somente após revisar a extração e confirmar a operação.

### 5. Listar Snapshots
Exiba todos os backups criptografados no repositório S3:
```bash
abm snapshots
```

### 6. Status do Servidor
Obtenha detalhes de versão, espaço utilizado, contagem de backups e retenção ativa:
```bash
abm status
```

### 7. Histórico e Relatórios
Visualize métricas sobre tempos de execução, sucessos, falhas e últimas execuções:
```bash
abm report
```

### 8. Gerenciamento do Cron
Instale, exiba ou remova o backup automático no agendador Cron do Linux:
```bash
abm schedule
```

---

## 📁 Estrutura de Diretórios v2

```
/opt/autoniza-backup/
├── backup.sh          # Wrapper legível de backup
├── restore.sh         # Wrapper legível de restore
├── update.sh          # Wrapper legível de atualização
├── uninstall.sh       # Wrapper legível de desinstalação
├── bin/
│   └── abm            # Executável principal da CLI
├── lib/               # Módulos e bibliotecas bash
│   ├── config.sh      # Carregamento e validação de configs
│   ├── doctor.sh      # Verificação de integridade e Health Score
│   ├── snapshots.sh   # Listagem e busca de snapshots
│   ├── schedule.sh    # Instalação e teste do Cron
│   ├── retention.sh   # Aplicação de retenção
│   ├── backup.sh      # Lógica de backup modularizada
│   ├── restore.sh     # Lógica de restore interativo/direto
│   ├── logger.sh      # Funções de log com cores
│   ├── metrics.sh     # Parser de saída do restic
│   ├── notify.sh      # Telemetria de webhooks
│   └── utils.sh       # Utilitários de sistema
├── hooks/             # Scripts customizáveis (pre-backup, post-backup, etc.)
├── logs/              # Logs detalhados
├── dumps/             # Dumps locais temporários
├── reports/           # Relatórios gerados em txt e html
└── restore/           # Diretório de restauração local
```

---

## 🔔 Notificações Enterprise via n8n

O Autoniza Backup Manager envia notificações em JSON formatado contendo status da execução, metadados do sistema, métricas de arquivos/tamanhos e detalhes de erros para auditoria rápida.

### Payload de Sucesso
```json
{
  "status": "success",
  "server": "coolify-prod",
  "environment": "production",
  "hostname": "coolify",
  "repository": "coolifybkp",
  "snapshot": "a82aa91c",
  "metrics": {
    "duration": "6.04s",
    "files": 103,
    "size": "2.016 MiB",
    "storage_used": "692.727 KiB"
  },
  "system": {
    "os": "Ubuntu 24.04",
    "kernel": "6.8.0",
    "docker": "28.3.0",
    "restic": "0.18.0",
    "abm": "2.0.0"
  },
  "message": "Backup concluído com sucesso."
}
```

---

## 🤝 Contribuição

Sinta-se à vontade para abrir issues ou enviar pull requests!

## 📄 Licença

Distribuído sob a licença MIT.
