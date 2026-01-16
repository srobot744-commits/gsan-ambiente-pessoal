#!/bin/bash
EAR_DIR="/root/docker/jboss5/deploy/gcom.ear"
WAR_CLASSES="$EAR_DIR/gcom.war/WEB-INF/classes"

# 1) Criar pasta de backup com timestamp
BACKUP_BASE="$EAR_DIR/backup-$(date +%Y%m%d-%H%M%S)"
BACKUP_SEG_ACESSO="$BACKUP_BASE/seguranca_acesso_war"
mkdir -p "$BACKUP_SEG_ACESSO"

# 2) Se existir o pacote de seguranca/acesso no WAR, mover para o backup
if [ -d "$WAR_CLASSES/gcom/seguranca/acesso" ]; then
    echo "Movendo $WAR_CLASSES/gcom/seguranca/acesso -> $BACKUP_SEG_ACESSO/"
    mv "$WAR_CLASSES/gcom/seguranca/acesso" "$BACKUP_SEG_ACESSO/"
else
    echo "ATENÇÃO: diretório $WAR_CLASSES/gcom/seguranca/acesso NÃO existe no WAR."
fi
