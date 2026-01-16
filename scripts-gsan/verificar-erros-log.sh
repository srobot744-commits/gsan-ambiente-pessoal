#!/bin/bash
# ==========================================================
# SCRIPT: Verificação de Erros no Log do JBoss (GSAN)
# Autor: ChatGPT + Cláudio
# Função: localizar erros, exceptions e fatals no server.log
# Uso: ./verificar-erros-log.sh [filtro-opcional]
# Ex:  ./verificar-erros-log.sh hibernate
#      ./verificar-erros-log.sh datasource
# ==========================================================

LOG_DIR="/root/docker/jboss5/log"
LOG_FILE="$LOG_DIR/server.log"
OUT_FILE="$LOG_DIR/server-log-erros.txt"

echo "=========================================================="
echo " ANALISANDO ERROS NO SERVER.LOG"
echo " Log:      $LOG_FILE"
echo " Saída:    $OUT_FILE"
echo " Filtro:   ${1:-nenhum}"
echo "=========================================================="
echo ""

# Verificar existência do server.log
if [ ! -f "$LOG_FILE" ]; then
    echo "[ERRO] Arquivo server.log não encontrado em $LOG_FILE"
    exit 1
fi

# Criar arquivo de saída
echo "==== ERROS EXTRAÍDOS EM $(date) ====" > "$OUT_FILE"

# Comandos base — erros que realmente importam
BASE_GREP='grep -E "ERROR|Exception|FATAL|SEVERE|NullPointerException|ClassCastException|LinkageError|VerifyError"'

# Executar com ou sem filtro adicional
if [ -n "$1" ]; then
    echo "[*] Aplicando filtro adicional: $1"
    eval "$BASE_GREP \"$LOG_FILE\" | grep -i \"$1\"" >> "$OUT_FILE"
else
    eval "$BASE_GREP \"$LOG_FILE\"" >> "$OUT_FILE"
fi

echo "[OK] Extração concluída."
echo "Arquivo gerado: $OUT_FILE"
echo ""

# Mostrar os 30 últimos erros encontrados
echo "---------------- ÚLTIMOS 30 ERROS ENCONTRADOS ----------------"
tail -n 30 "$OUT_FILE"
echo "--------------------------------------------------------------"
echo ""

# Perguntar se deseja seguir monitorando o log
read -p "Deseja monitorar o log em tempo real? (s/n) " resp
if [[ "$resp" =~ ^[sS]$ ]]; then
    echo "Iniciando tail -f do server.log (Ctrl + C para sair)..."
    echo ""
    eval "$BASE_GREP \"$LOG_FILE\"" | tail -f "$LOG_FILE"
fi

exit 0
