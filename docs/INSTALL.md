# Guia de Instalação - Autoniza Backup Manager

## Pré-requisitos

- Ubuntu/Debian (testado) ou outra distribuição Linux
- Docker instalado e configurado
- Acesso a um bucket S3/MinIO

## Instalação

### 1. Executar o instalador

```bash
sudo bash install.sh
```

O instalador irá:
- Instalar dependências: `restic`, `jq`, `yq`
- Criar diretórios em `/opt/autoniza-backup`
- Copiar todos os arquivos do projeto
- Criar `config/config.env` e `config/backup.yaml` a partir dos exemplos

### 2. Configurar credenciais

Edite o arquivo de configuração:

```bash
sudo nano /opt/autoniza-backup/config/config.env
```

Preencha as variáveis:

```env
RESTIC_REPOSITORY="s3:https://seu-minio.exemplo.com/nome-do-bucket"
AWS_ACCESS_KEY_ID="sua_access_key"
AWS_SECRET_ACCESS_KEY="sua_secret_key"
RESTIC_PASSWORD="senha_forte_para_criptografia"
```

### 3. Configurar o backup

Edite o arquivo YAML:

```bash
sudo nano /opt/autoniza-backup/config/backup.yaml
```

Configure os bancos de dados e pastas que deseja incluir no backup.

### 4. Testar o backup

```bash
sudo /opt/autoniza-backup/backup.sh
```

### 5. Agendar no Cron

```bash
sudo crontab -e
```

Adicione a linha (backup diário às 2h):

```cron
0 2 * * * /opt/autoniza-backup/backup.sh >> /opt/autoniza-backup/logs/cron.log 2>&1
```

## Verificação

Para verificar se a instalação foi bem-sucedida:

```bash
ls -la /opt/autoniza-backup/
ls -la /opt/autoniza-backup/config/
```

## Atualização

```bash
cd /caminho/do/projeto
git fetch origin feature/v2-evolution
git merge --ff-only origin/feature/v2-evolution
sudo bash update.sh
```

Evite `git pull` cego em produção. A atualização deve preservar `config.env` e `backup.yaml`, validar fast-forward e manter backup de rollback em `/opt/autoniza-backup/backups/update_<timestamp>/`.

## Pinagem de Dependências

O instalador prioriza pacotes da distribuição quando disponíveis. Para fallback via GitHub Releases, use versões pinadas:

```bash
sudo RESTIC_VERSION=0.18.0 YQ_VERSION=4.45.4 bash install.sh
```

Não use URLs `latest` para Restic, yq ou imagens Docker em ambientes operacionais.
