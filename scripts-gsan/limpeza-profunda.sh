#!/bin/bash
# ==========================================================
# SCRIPT: Limpeza Profunda do Ambiente GSAN
# VERSÃO: 48 (2025-11-27)
# ==========================================================
# GSAN - LIMPEZA PROFUNDA (Versão V48)
# ==========================================================
# Responsável por:
# - Parar e remover containers JBoss (servidor e temporários)
# - Limpar logs e deploys quebrados
# - Preservar código-fonte em /opt/gsan (NÃO faz git reset!)
# - Fazer backup/restauração da pasta /opt/gsan/config
# - Verificar integridade de diretórios principais
# ==========================================================

CONF_DIR="/root/docker/jboss5/conf"
DEPLOY_DIR="/root/docker/jboss5/deploy"
LOG_DIR="/root/docker/jboss5/log"
GSAN_DIR="/opt/gsan"

echo "=========================================================="
echo "      INICIANDO LIMPEZA PROFUNDA DO AMBIENTE (V48)"
echo "=========================================================="

# 1️ Parar e remover containers existentes
echo "[1/6] Parando e removendo containers JBoss..."
docker stop jboss-servidor &> /dev/null
docker rm jboss-servidor &> /dev/null
docker rm -f jboss-temp-extracao &> /dev/null
docker rm -f jboss-temp-jms &> /dev/null
echo "   -> Containers encerrados e removidos."

# 2️ Limpeza de logs e deploys quebrados
echo "[2/6] Limpando logs e deploys quebrados..."
if [ -d "$LOG_DIR" ]; then
  sudo rm -rf "${LOG_DIR:?}"/*
  echo "   -> Logs limpos em $LOG_DIR."
else
  echo "   -> Diretório de logs não encontrado: $LOG_DIR (ok)."
fi

if [ -d "$DEPLOY_DIR" ]; then
  sudo rm -rf "${DEPLOY_DIR:?}/gcom.ear"
  echo "   -> Deploy do gcom.ear removido de $DEPLOY_DIR."
else
  echo "   -> Diretório de deploy não encontrado: $DEPLOY_DIR (ok)."
fi

# 3️ Backup e preservação da pasta de configuração
echo "[3/6] Backup da pasta /opt/gsan/config..."
if [ -d "$GSAN_DIR/config" ]; then
  sudo rm -rf /tmp/gsan_config_backup
  sudo mkdir -p /tmp/gsan_config_backup
  sudo cp -r "$GSAN_DIR/config/" /tmp/gsan_config_backup/
  echo "   -> Backup criado em /tmp/gsan_config_backup"
else
  echo "   -> Pasta /opt/gsan/config não existe, será criada depois."
fi

# 4️ NÃO restaurar código-fonte do GSAN via git
echo "[4/6] Preservando código-fonte do GSAN em $GSAN_DIR"
echo "   -> Nenhum 'git reset' ou 'git clean' será executado."
if [ -d "$GSAN_DIR/.git" ]; then
  echo "   -> Repositório Git detectado apenas para controle de versão manual."
else
  echo "   -> Atenção: $GSAN_DIR não parece ser um repositório Git."
fi

# 5️ Restauração automática da pasta config
echo "[5/6] Restaurando pasta /opt/gsan/config..."
if [ -d /tmp/gsan_config_backup ]; then
  sudo rm -rf "$GSAN_DIR/config"
  sudo mkdir -p "$GSAN_DIR"
  sudo cp -r /tmp/gsan_config_backup "$GSAN_DIR/config"
  sudo chmod -R 777 "$GSAN_DIR/config"
  echo "   ✅ Pasta /opt/gsan/config restaurada do backup temporário."
else
  echo "   ⚙️  Backup não encontrado — criando nova estrutura /opt/gsan/config..."
  sudo mkdir -p "$GSAN_DIR/config"
  sudo chmod 777 "$GSAN_DIR/config"
fi

# (Opcional) Garantir proteção da pasta config no .gitignore, se existir repo
if [ -f "$GSAN_DIR/.gitignore" ]; then
  if ! grep -q "^config/$" "$GSAN_DIR/.gitignore" 2>/dev/null; then
    echo "config/" | sudo tee -a "$GSAN_DIR/.gitignore" > /dev/null
    echo "   -> Adicionada entrada 'config/' ao .gitignore."
  else
    echo "   -> Pasta config já protegida no .gitignore."
  fi
fi

# 6️ Revisão final de integridade
echo "[6/6] Revisando integridade de diretórios..."
for path in "$CONF_DIR" "$DEPLOY_DIR" "$GSAN_DIR" "$GSAN_DIR/config"; do
  if [ -d "$path" ]; then
    echo "   ✅ OK: $path"
  else
    echo "   ❌ Faltando: $path"
  fi
done

echo "=========================================================="
echo "   LIMPEZA PROFUNDA CONCLUÍDA COM SUCESSO (V48 - SAFE)"
echo "   -> Código-fonte em /opt/gsan preservado."
echo "=========================================================="
