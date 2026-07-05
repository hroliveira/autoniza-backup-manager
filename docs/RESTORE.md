# Guia de Restauração - Autoniza Backup Manager

## Comandos Disponíveis

### Listar snapshots

```bash
sudo /opt/autoniza-backup/bin/abm snapshots
```

### Fluxo interativo seguro

```bash
sudo /opt/autoniza-backup/restore.sh
```

### Extrair um snapshot específico em modo seguro

```bash
sudo /opt/autoniza-backup/restore.sh --snapshot <snapshot-id>
```

Por padrão, o comando apenas extrai o snapshot para revisão. Ele não escreve em containers, bancos ou caminhos originais.

### Simular a extração

```bash
sudo /opt/autoniza-backup/restore.sh --snapshot <snapshot-id> --dry-run
```

### Especificar diretório de extração

```bash
sudo /opt/autoniza-backup/restore.sh --snapshot <snapshot-id> --target /tmp/minha-restauracao
```

### Aplicar em containers/caminhos originais

```bash
sudo /opt/autoniza-backup/restore.sh --snapshot <snapshot-id> --target /tmp/minha-restauracao --apply
```

Use `--apply` somente depois de revisar a extração. Essa opção pode sobrescrever bancos e arquivos nos destinos originais e exige confirmação digitando `APLICAR`.

Em automações controladas, a confirmação pode ser explicitada com:

```bash
sudo ABM_RESTORE_CONFIRM=APPLY /opt/autoniza-backup/restore.sh --snapshot <snapshot-id> --apply
```

## Processo de Restauração

1. Liste os snapshots disponíveis e anote o ID desejado.
2. Execute a extração segura para um diretório de revisão.
3. Revise dumps, arquivos e volumes extraídos.
4. Aplique manualmente ou rode novamente com `--apply` se a escrita nos destinos originais for intencional.

## Pós-Restauração

Após a restauração, os arquivos estarão em `/opt/autoniza-backup/restore/<snapshot-id>/`.

### Restaurar PostgreSQL

```bash
cat /opt/autoniza-backup/restore/<snapshot-id>/<nome>_postgres.sql | \
  docker exec -i <container-postgres> psql -U <usuario> <database>
```

### Restaurar MySQL/MariaDB

```bash
cat /opt/autoniza-backup/restore/<snapshot-id>/<nome>_mysql.sql | \
  docker exec -i <container-mysql> mysql -u <usuario> -p<senha> <database>
```

### Restaurar pastas do sistema

```bash
cp -a /opt/autoniza-backup/restore/<snapshot-id>/data/... /data/...
```

## Avisos

- A restauração sem `--apply` **NÃO** sobrescreve dados de produção automaticamente.
- A opção `--apply` pode alterar bancos, containers e caminhos originais.
- Sempre revise os dados antes de copiá-los para produção.
- Faça a restauração em um ambiente de teste sempre que possível.
