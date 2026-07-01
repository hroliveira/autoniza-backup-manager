Crie um projeto chamado autoniza-backup-manager.

Objetivo:
Criar um Backup Manager em Bash para servidores Docker/Coolify, usando Restic com destino S3/MinIO, com configuração via YAML, logs, retenção, verificação e futura integração com Telegram/n8n.

Stack:
- Bash
- Docker CLI
- Restic
- yq
- jq
- cron
- MinIO/S3
- PostgreSQL pg_dump
- MySQL/MariaDB mysqldump
- Redis redis-cli

Estrutura do projeto:

autoniza-backup-manager/
├── README.md
├── install.sh
├── update.sh
├── backup.sh
├── restore.sh
├── uninstall.sh
├── config/
│   ├── config.env.example
│   └── backup.yaml.example
├── lib/
│   ├── logger.sh
│   ├── docker.sh
│   ├── restic.sh
│   ├── postgres.sh
│   ├── mysql.sh
│   ├── redis.sh
│   ├── notify.sh
│   ├── report.sh
│   └── utils.sh
├── hooks/
│   ├── pre-backup.sh.example
│   └── post-backup.sh.example
├── docs/
│   ├── INSTALL.md
│   ├── RESTORE.md
│   ├── MINIO.md
│   └── COOLIFY.md
└── examples/
    ├── coolify.yaml
    ├── docker-compose-apps.yaml
    └── n8n-webhook.json

Funcionalidades obrigatórias:

1. install.sh
- Instalar dependências: restic, jq, yq.
- Criar diretório /opt/autoniza-backup.
- Copiar arquivos do projeto.
- Criar config.env a partir do exemplo, se não existir.
- Criar backup.yaml a partir do exemplo, se não existir.
- Criar diretórios logs, tmp, dumps, reports.
- Não sobrescrever arquivos existentes.
- Exibir próximos passos.

2. config.env.example
Variáveis:
RESTIC_REPOSITORY=s3:https://api-minio.hro.dev.br/coolifybkp
AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
RESTIC_PASSWORD=
BACKUP_ROOT=/opt/autoniza-backup

3. backup.yaml.example
Configuração:
server:
  name: coolify-prod
  environment: production

retention:
  daily: 7
  weekly: 4
  monthly: 12

checks:
  restic_check: true
  read_data_subset: "1%"

folders:
  - /data/coolify

postgres:
  - name: coolify
    container: coolify-db
    database: coolify
    user: coolify

mysql: []

redis: []

notifications:
  enabled: false
  webhook_url: ""

4. backup.sh
- Carregar config.env.
- Carregar backup.yaml com yq.
- Criar pasta temporária por data.
- Executar hooks/pre-backup.sh se existir.
- Fazer dump dos bancos PostgreSQL configurados.
- Fazer dump dos bancos MySQL/MariaDB configurados.
- Fazer snapshot Redis quando configurado.
- Verificar se os dumps foram criados e não estão vazios.
- Executar restic backup incluindo:
  - folders definidos no YAML
  - dumps temporários
- Aplicar retenção:
  --keep-daily
  --keep-weekly
  --keep-monthly
  --prune
- Executar restic check opcional.
- Gerar relatório simples em texto e HTML.
- Executar hooks/post-backup.sh se existir.
- Enviar notificação via webhook se ativado.
- Limpar tmp.
- Em caso de erro, registrar log e enviar notificação de falha.

5. restore.sh
- Listar snapshots.
- Permitir escolher snapshot por ID.
- Restaurar para /opt/autoniza-backup/restore/<snapshot-id>.
- Não sobrescrever dados em produção automaticamente.
- Exibir instruções para restaurar PostgreSQL.

6. lib/logger.sh
Funções:
log_info
log_warn
log_error
log_success

7. lib/restic.sh
Funções:
restic_check_repo
restic_init_if_needed
restic_run_backup
restic_apply_retention
restic_verify

8. lib/postgres.sh
Função:
backup_postgres(container, database, user, output_file)

Usar:
docker exec CONTAINER pg_dump -U USER DATABASE > output.sql

9. lib/mysql.sh
Função:
backup_mysql(container, database, user, password, output_file)

10. lib/redis.sh
Função:
backup_redis(container, output_file)

11. lib/notify.sh
Enviar JSON para webhook:
{
  "status": "success|error",
  "server": "...",
  "environment": "...",
  "snapshot": "...",
  "duration": "...",
  "message": "..."
}

12. README.md
Incluir:
- O que é o projeto.
- Como instalar.
- Como configurar MinIO.
- Como configurar Restic.
- Como agendar no cron.
- Como restaurar.
- Exemplo para Coolify.

13. Cron sugerido
0 2 * * * /opt/autoniza-backup/backup.sh >> /opt/autoniza-backup/logs/cron.log 2>&1

Critérios de qualidade:
- Bash com set -Eeuo pipefail.
- Sem secrets hardcoded.
- Logs claros.
- Scripts idempotentes.
- Código modular.
- Compatível com Ubuntu/Debian.
- Não apagar dados de produção automaticamente.