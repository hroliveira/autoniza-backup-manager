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
git clone https://github.com/hroliveira/autoniza-backup-manager.git
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


## 🔔 Notificações Enterprise via n8n

O Autoniza Backup Manager suporta telemetria avançada enviando payloads JSON ricos para um Webhook do n8n, permitindo auditorias, histórico de execuções e dashboards.

### Configuração

1. No arquivo `/opt/autoniza-backup/config/backup.yaml`, ative as notificações e defina a URL do seu Webhook:
   ```yaml
   notifications:
     enabled: true
     webhook_url: "https://seu-n8n.dominio.com/webhook/caminho-do-seu-webhook"
   ```

### Estrutura Completa do Payload

#### Exemplo de Sucesso
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
  "execution": {
    "id": "20260702-004313-a82aa91c",
    "started_at": "2026-07-02T00:43:07-03:00",
    "finished_at": "2026-07-02T00:43:13-03:00"
  },
  "system": {
    "os": "Ubuntu 24.04",
    "kernel": "6.8.0",
    "docker": "28.3.0",
    "restic": "0.18.0",
    "abm": "1.3.0"
  },
  "message": "Backup concluído com sucesso.",
  "timestamp": "2026-07-02T00:43:13-03:00"
}
```

#### Exemplo de Erro
```json
{
  "status": "error",
  "server": "coolify-prod",
  "environment": "production",
  "hostname": "coolify",
  "repository": "coolifybkp",
  "snapshot": null,
  "metrics": {
    "duration": "4.92s",
    "files": 31,
    "size": "1.12 MiB",
    "storage_used": "0 B"
  },
  "execution": {
    "id": "20260702-004313-error",
    "started_at": "2026-07-02T00:43:07-03:00",
    "finished_at": "2026-07-02T00:43:12-03:00"
  },
  "system": {
    "os": "Ubuntu 24.04",
    "kernel": "6.8.0",
    "docker": "28.3.0",
    "restic": "0.18.0",
    "abm": "1.3.0"
  },
  "error": {
    "stage": "restic",
    "code": "RESTIC_CONNECTION_ERROR",
    "details": "S3 API request failed: connection refused"
  },
  "message": "Falha ao executar o backup.",
  "timestamp": "2026-07-02T00:43:12-03:00"
}
```

### Campos do Payload
- `status`: Estado final da execução (`success` ou `error`).
- `metrics`: Métricas de desempenho coletadas do Restic e temporizadores.
- `execution`: Timestamps ISO e ID único da execução (`id`).
- `system`: Metadados do servidor incluindo sistema operacional, kernel, docker, restic e versão do ABM.
- `error`: Detalhes de falhas do estágio, códigos padronizados (ex: `PG_DUMP_FAILED`, `RESTIC_CONNECTION_ERROR`) e mensagem do erro.

### Integração no n8n, Dashboards e Histórico
1. **Consumo no n8n**: Configure um nó **Webhook** configurado para receber requisições do tipo POST. Conecte um nó **IF** para verificar `status == "success"`.
2. **Alertas Instantâneos**: Utilize nós do Telegram, Slack ou Discord para formatar mensagens ricas em Markdown com o ID de execução e as métricas.
3. **Dashboards e Auditoria**: Envie os payloads diretamente para bancos de dados como PostgreSQL, InfluxDB ou Elasticsearch para montar visualizações no Grafana ou Kibana, acompanhando o crescimento de volume armazenado e tempos médios de execução.

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
