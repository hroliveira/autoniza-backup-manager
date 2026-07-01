# 🔄 Autoniza Backup Manager

**Backup Manager para servidores Docker/Coolify** — automatiza backups de bancos de dados (PostgreSQL, MySQL, Redis) e pastas do sistema, armazenando tudo criptografado no S3/MinIO via Restic, com retenção configurável, verificação de integridade e notificações.

---

## ✨ Funcionalidades

- 📦 **Backup de bancos:** PostgreSQL (`pg_dump`), MySQL/MariaDB (`mysqldump`) e Redis (`redis-cli SAVE`)
- 🗂️ **Backup de pastas:** Diretórios do sistema como `/data/coolify`
- 🔐 **Criptografia:** Todos os backups são criptografados com Restic
- ☁️ **Destino S3:** Compatível com MinIO, AWS S3, DigitalOcean Spaces, etc.
- 📅 **Retenção:** Política configurável (diária, semanal, mensal) com `restic forget --prune`
- ✅ **Verificação:** `restic check` opcional com subset de dados
- 📊 **Relatórios:** Geração automática de relatórios em texto e HTML
- 🔔 **Notificações:** Webhook para integração com n8n, Telegram, etc.
- 🔌 **Hooks:** Scripts personalizáveis pré e pós-backup
- 🐳 **Docker:** Integração total com containers Docker

---

## 🚀 Instalação Rápida

```bash
# Clone ou copie os arquivos para o servidor
git clone https://github.com/seu-usuario/autoniza-backup-manager.git
cd autoniza-backup-manager

# Execute o instalador (como root)
sudo bash install.sh
```

## ⚙️ Configuração

### 1. Credenciais

Edite `/opt/autoniza-backup/config/config.env`:

```env
RESTIC_REPOSITORY="s3:https://api-minio.seudominio.com/coolifybkp"
AWS_ACCESS_KEY_ID="sua_access_key"
AWS_SECRET_ACCESS_KEY="sua_secret_key"
RESTIC_PASSWORD="senha_forte_para_criptografia"
```

### 2. Backup

Edite `/opt/autoniza-backup/config/backup.yaml`:

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
  - name: coolify
    container: coolify-db
    database: coolify
    user: coolify

redis:
  - name: coolify
    container: coolify-redis
```

## ▶️ Uso

### Executar backup manualmente

```bash
sudo /opt/autoniza-backup/backup.sh
```

### Listar snapshots

```bash
sudo /opt/autoniza-backup/restore.sh list
```

### Restaurar um snapshot

```bash
sudo /opt/autoniza-backup/restore.sh restore <snapshot-id>
```

### Restaurar o mais recente

```bash
sudo /opt/autoniza-backup/restore.sh latest
```

## ⏰ Agendar no Cron

```cron
0 2 * * * /opt/autoniza-backup/backup.sh >> /opt/autoniza-backup/logs/cron.log 2>&1
```

## 📁 Estrutura do Projeto

```
/opt/autoniza-backup/
├── backup.sh          # Script principal de backup
├── restore.sh         # Script de restauração
├── update.sh          # Atualização do sistema
├── uninstall.sh       # Desinstalação
├── config/
│   ├── config.env     # Credenciais (editar)
│   └── backup.yaml    # Configuração do backup (editar)
├── lib/               # Bibliotecas bash
│   ├── logger.sh      # Logging com cores e timestamp
│   ├── utils.sh       # Utilitários diversos
│   ├── restic.sh      # Wrapper Restic
│   ├── docker.sh      # Utilitários Docker
│   ├── postgres.sh    # Backup PostgreSQL
│   ├── mysql.sh       # Backup MySQL/MariaDB
│   ├── redis.sh       # Snapshot Redis
│   ├── notify.sh      # Notificações webhook
│   └── report.sh      # Relatórios texto/HTML
├── hooks/             # Scripts customizáveis
│   ├── pre-backup.sh  # Executado antes do backup
│   └── post-backup.sh # Executado após o backup
├── docs/              # Documentação
├── examples/          # Exemplos de configuração
├── logs/              # Logs do backup
├── tmp/               # Arquivos temporários
├── dumps/             # Dumps locais
├── reports/           # Relatórios gerados
└── restore/           # Dados restaurados
```

## 📚 Documentação

- [Guia de Instalação](docs/INSTALL.md)
- [Guia de Restauração](docs/RESTORE.md)
- [Configuração do MinIO/S3](docs/MINIO.md)
- [Integração com Coolify](docs/COOLIFY.md)

## 🛠 stack

| Ferramenta   | Função                            |
|-------------|-----------------------------------|
| Bash        | Script principal                  |
| Docker CLI  | Execução em containers            |
| Restic      | Backup criptografado para S3      |
| yq          | Parse de YAML                     |
| jq          | Processamento JSON                |
| cron        | Agendamento                       |
| MinIO/S3    | Armazenamento dos backups         |
| pg_dump     | Dump PostgreSQL                   |
| mysqldump   | Dump MySQL/MariaDB                |
| redis-cli   | Snapshot Redis                    |

## 🤝 Contribuição

Contribuições são bem-vindas! Sinta-se à vontade para abrir issues ou enviar pull requests.

## 📄 Licença

MIT
