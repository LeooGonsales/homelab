#!/usr/bin/env bash
# Backup do Immich para o HD externo: dump do banco (PostgreSQL) + cópia das fotos.
# Segue a recomendação da documentação do Immich: https://docs.immich.app/administration/backup-and-restore
#
# Uso manual:   ./backup-immich.sh
# Agendado:     crontab -e  →  30 3 * * * /home/leonardo/homelab/scripts/backup-immich.sh >> /home/leonardo/backup-immich.log 2>&1
#
# Ajuste as 3 variáveis abaixo antes de usar.

set -euo pipefail

IMMICH_DIR="/home/leonardo/immich"           # pasta onde está o docker-compose.yml e o .env do Immich
HD_EXTERNO="/media/leonardo/HD_EXTERNO"      # ponto de montagem do HD externo
KEEP_DUMPS=14                                # quantos dumps do banco manter

DEST="$HD_EXTERNO/backup-immich"
STAMP="$(date +%F_%H%M)"

log() { echo "[$(date '+%F %T')] $*"; }

command -v rsync > /dev/null || { log "ERRO: rsync não instalado (sudo apt install rsync)"; exit 1; }

# 1. Só continua se o HD externo estiver montado (senão o backup iria para o disco interno).
if ! mountpoint -q "$HD_EXTERNO"; then
  log "ERRO: $HD_EXTERNO não está montado. Backup cancelado."
  exit 1
fi

# 2. Lê do .env só as variáveis necessárias (sem executar o arquivo inteiro).
get_env() { grep -E "^$1=" "$IMMICH_DIR/.env" | tail -n1 | cut -d= -f2- | tr -d '"'"'"; }
DB_USERNAME="$(get_env DB_USERNAME)"
UPLOAD_LOCATION="$(get_env UPLOAD_LOCATION)"
[ -n "$DB_USERNAME" ] && [ -n "$UPLOAD_LOCATION" ] || { log "ERRO: DB_USERNAME ou UPLOAD_LOCATION vazio no .env"; exit 1; }

# UPLOAD_LOCATION pode ser relativo à pasta do Immich (ex.: ./library).
case "$UPLOAD_LOCATION" in
  /*) UPLOAD_PATH="$UPLOAD_LOCATION" ;;
  *)  UPLOAD_PATH="$IMMICH_DIR/${UPLOAD_LOCATION#./}" ;;
esac

mkdir -p "$DEST/db" "$DEST/fotos"

# 3. Dump do banco. Sem "-t": num cron não há terminal, e o -t pode corromper a saída.
log "Gerando dump do banco..."
docker exec immich_postgres pg_dumpall --clean --if-exists --username="$DB_USERNAME" \
  | gzip > "$DEST/db/immich_$STAMP.sql.gz.tmp"
mv "$DEST/db/immich_$STAMP.sql.gz.tmp" "$DEST/db/immich_$STAMP.sql.gz"
log "Dump salvo: $DEST/db/immich_$STAMP.sql.gz ($(du -h "$DEST/db/immich_$STAMP.sql.gz" | cut -f1))"

# 4. Mantém só os KEEP_DUMPS dumps mais recentes.
ls -1t "$DEST"/db/immich_*.sql.gz 2>/dev/null | tail -n +$((KEEP_DUMPS + 1)) | xargs -r rm --

# 5. Copia as fotos. Sem --delete de propósito: se uma foto sumir do servidor, a cópia continua no HD.
log "Copiando fotos de $UPLOAD_PATH ..."
rsync -a --info=stats1 "$UPLOAD_PATH/" "$DEST/fotos/"

log "Backup concluído."
