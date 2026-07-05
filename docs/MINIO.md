# Configuração do MinIO/S3 - Autoniza Backup Manager

## Visão Geral

O Autoniza Backup Manager utiliza o Restic para armazenar backups em buckets S3 compatíveis, como MinIO, AWS S3, DigitalOcean Spaces, etc.

## Configurando o MinIO

### 1. Instalar MinIO (Docker)

```yaml
# docker-compose.yml
version: '3.8'

services:
  minio:
    image: minio/minio:RELEASE.2026-06-13T11-33-47Z
    container_name: minio
    command: server /data --console-address ":9001"
    ports:
      - "9000:9000"
      - "9001:9001"
    volumes:
      - minio_data:/data
    environment:
      MINIO_ROOT_USER: minioadmin
      MINIO_ROOT_PASSWORD: ${MINIO_ROOT_PASSWORD:?defina uma senha forte}
    restart: unless-stopped

volumes:
  minio_data:
```

### 2. Iniciar o MinIO

```bash
docker compose up -d
```

### 3. Criar um Bucket

Acesse o console do MinIO em `http://localhost:9001` e crie um bucket chamado `coolifybkp`.

Ou use a CLI:

```bash
mc alias set myminio http://localhost:9000 minioadmin '<senha-forte>'
mc mb myminio/coolifybkp
```

## Configurando no Backup Manager

Edite `/opt/autoniza-backup/config/config.env`:

```env
RESTIC_REPOSITORY="s3:http://localhost:9000/coolifybkp"
AWS_ACCESS_KEY_ID="minioadmin"
AWS_SECRET_ACCESS_KEY="<secret-key-forte>"
RESTIC_PASSWORD="sua-senha-forte-aqui"
```

### Para MinIO remoto (exemplo com domínio):

```env
RESTIC_REPOSITORY="s3:https://api-minio.seudominio.com/coolifybkp"
AWS_ACCESS_KEY_ID="sua-access-key"
AWS_SECRET_ACCESS_KEY="sua-secret-key"
RESTIC_PASSWORD="sua-senha-forte-aqui"
```

## Verificar Conexão

```bash
restic snapshots
```

Se tudo estiver configurado corretamente, você verá a lista de snapshots (ou uma mensagem informando que ainda não há snapshots).
