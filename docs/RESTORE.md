# Guia de Restauração - Autoniza Backup Manager

## Comandos Disponíveis

### Listar snapshots

```bash
sudo /opt/autoniza-backup/restore.sh list
```

### Restaurar um snapshot específico

```bash
sudo /opt/autoniza-backup/restore.sh restore <snapshot-id>
```

### Restaurar o snapshot mais recente

```bash
sudo /opt/autoniza-backup/restore.sh latest
```

### Especificar diretório de destino

```bash
sudo /opt/autoniza-backup/restore.sh restore <snapshot-id> --target /tmp/minha-restauracao
```

## Processo de Restauração

1. Liste os snapshots disponíveis e anote o ID desejado.
2. Execute o comando de restauração.
3. Confirme a operação quando solicitado.

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

## ⚠ Avisos

- A restauração **NÃO** sobrescreve dados de produção automaticamente.
- Sempre revise os dados antes de copiá-los para produção.
- Faça a restauração em um ambiente de teste sempre que possível.
