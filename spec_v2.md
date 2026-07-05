# SPECIFICATION
Autoniza Backup Manager
Version 2.0
Enterprise Backup Platform

============================================================
OBJETIVO
============================================================

Transformar o projeto atual em uma plataforma completa de Backup e Restore para servidores Linux, Docker e Coolify.

O projeto deve possuir uma CLI única chamada:

abm

Toda interação será através dela.

Não remover compatibilidade com os scripts atuais.

backup.sh
restore.sh
install.sh
update.sh
uninstall.sh

passam a ser wrappers da CLI.

============================================================
ARQUITETURA
============================================================

Criar:

bin/
    abm

lib/
    backup.sh
    restore.sh
    metrics.sh
    notify.sh
    system.sh
    docker.sh
    postgres.sh
    mysql.sh
    redis.sh
    retention.sh
    config.sh
    logger.sh
    utils.sh
    doctor.sh
    schedule.sh
    snapshots.sh

============================================================
COMANDOS
============================================================

abm backup

Executa backup completo.

------------------------------------------------------------

abm restore

Modo interativo.

Fluxo:

Listar snapshots disponíveis.

Exemplo:

1)
2026-07-01 02:00

2)
2026-06-30 02:00

3)
2026-06-29 02:00

4)
Informar Snapshot ID

Depois perguntar:

Restaurar:

( ) Banco

( ) Arquivos

( ) Docker Volumes

( ) Tudo

Mostrar resumo.

Solicitar confirmação.

Executar restore.

Enviar webhook.

------------------------------------------------------------

abm restore --snapshot xxxx

Restore direto.

------------------------------------------------------------

abm restore --dry-run

Não altera nada.

Apenas mostra o que seria restaurado.

------------------------------------------------------------

abm snapshots

Executa:

restic snapshots

Formatar em tabela.

============================================================
DOCTOR
============================================================

Novo comando:

abm doctor

Executar verificações:

✔ Docker

✔ Docker daemon

✔ Restic

✔ PostgreSQL

✔ MySQL

✔ Redis

✔ Espaço em disco

✔ Cron

✔ Permissões

✔ MinIO

✔ Bucket

✔ Credenciais

✔ Webhook

✔ jq

✔ yq

✔ curl

✔ gzip

✔ pg_dump

✔ mysqldump

✔ redis-cli

Resultado:

PASS

WARNING

FAIL

No final:

Health Score

Exemplo:

97%

============================================================
STATUS
============================================================

abm status

Mostrar:

Servidor

Hostname

Versão

Último backup

Último snapshot

Quantidade snapshots

Repositório

Bucket

Espaço utilizado

Retenção

Cron

Webhook

============================================================
REPORT
============================================================

abm report

Mostrar:

Últimos backups

Tempo médio

Maior backup

Menor backup

Quantidade de falhas

Quantidade de sucessos

============================================================
CONFIG
============================================================

abm config

Menu:

Editar backup.yaml

Editar config.env

Mostrar configurações

Validar configuração

============================================================
SCHEDULE
============================================================

abm schedule

Menu:

Instalar Cron

Remover Cron

Mostrar Cron

Executar teste

============================================================
UPDATE
============================================================

abm update

Executar:

git pull

validar

copiar arquivos

preservar config

============================================================
BACKUP
============================================================

Refatorar backup atual.

Separar responsabilidades.

backup.sh

apenas orquestra.

Toda lógica fica em libs.

============================================================
RESTORE
============================================================

Implementar restore completo.

Arquivos

Volumes

PostgreSQL

MySQL

Redis

============================================================
SNAPSHOTS
============================================================

Nova biblioteca:

snapshots.sh

Funções:

listar snapshots

buscar snapshot

validar snapshot

============================================================
CONFIG
============================================================

Nova biblioteca:

config.sh

Carregar YAML.

Validar campos.

Valores padrão.

============================================================
RETENTION
============================================================

Nova biblioteca.

Aplicar:

daily

weekly

monthly

============================================================
DOCKER
============================================================

Backup de:

volumes

compose

configs

secrets

============================================================
HOOKS
============================================================

Adicionar:

before_backup

after_backup

before_restore

after_restore

============================================================
NOTIFICAÇÕES
============================================================

Enviar webhook em:

Backup

Restore

Doctor

Erro

============================================================
VERSÃO
============================================================

Criar:

VERSION

Atualizar automaticamente.

============================================================
CHANGELOG
============================================================

Adicionar CHANGELOG.md

============================================================
TESTES
============================================================

Criar pasta:

tests/

Adicionar testes para:

backup

restore

metrics

notify

doctor

============================================================
CI
============================================================

Adicionar GitHub Actions.

Pipeline:

bash syntax

shellcheck

yamllint

markdownlint

============================================================
DOCUMENTAÇÃO
============================================================

Atualizar README.

Adicionar:

Arquitetura

CLI

Instalação

Update

Restore

Doctor

Cron

Webhook

Hooks

Exemplos

============================================================
QUALIDADE
============================================================

Rodar:

shellcheck

bash -n

yamllint

markdownlint

============================================================
OBJETIVO FINAL
============================================================

O resultado deve parecer uma ferramenta profissional semelhante ao:

restic

rclone

docker

kubectl

com uma CLI única chamada:

abm

e preparada para evolução futura sem quebrar compatibilidade.