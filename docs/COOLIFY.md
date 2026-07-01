# Integração com Coolify - Autoniza Backup Manager

## Visão Geral

Coolify é uma plataforma de auto-hospedagem que utiliza Docker. O Autoniza Backup Manager foi projetado para fazer backup de aplicações Coolify.

## Configuração para Coolify

### Estrutura Típica Coolify

No Coolify, os dados geralmente estão em:

- `/data/coolify` - Dados da aplicação Coolify
- Containers nomeados como `coolify-db` (PostgreSQL), `coolify-redis`, etc.

### Arquivo de Configuração Exemplo

Crie `/opt/autoniza-backup/config/backup.yaml`:

```yaml
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

redis:
  - name: coolify
    container: coolify-redis
```

### Backup Manual

```bash
sudo /opt/autoniza-backup/backup.sh
```

### Agendamento no Coolify

No Coolify, você pode agendar o backup via:

1. **Cron (recomendado):** Adicione ao crontab do servidor
2. **Service Container:** Crie um container com o script montado
3. **GitHub Actions:** Dispare o backup via SSH

### Exemplo de Docker Service para Backup

Veja o arquivo `examples/docker-compose-apps.yaml` para um exemplo de container de backup.
