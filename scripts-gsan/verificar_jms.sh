#!/bin/bash
# ==========================================================
# SCRIPT: Verificação de Filas JMS no JBoss 5 (GSAN)
# VERSÃO: 10 (atualizado em 2025-11-11)
# ==========================================================
# Funções:
#  - Lista as filas JMS configuradas em jbossmq-destinations-service.xml
#  - Testa se estão ativas no servidor JBoss via JNDI
#  - Pode ser executado dentro ou fora do container jboss-servidor
# ==========================================================

CONF_DIR="/root/docker/jboss5/conf"
CONTAINER_NAME="jboss-servidor"
JMS_FILE="$CONF_DIR/jbossmq-destinations-service.xml"

echo "=========================================================="
echo "        VERIFICAÇÃO DE FILAS JMS (GSAN / JBoss 5)"
echo "=========================================================="

# 1️⃣ Verifica se o arquivo JMS existe
if [ ! -s "$JMS_FILE" ]; then
  echo "❌ Arquivo JMS não encontrado em: $JMS_FILE"
  echo "Execute a Fase 1 antes de rodar esta verificação."
  exit 1
fi

# 2️⃣ Lista de filas configuradas
echo "[1/4] Filas JMS configuradas em $JMS_FILE:"
grep -oP '(?<=<attribute name="JNDIName">)[^<]+' "$JMS_FILE" | sort
TOTAL_QUEUES=$(grep -c '<attribute name="JNDIName">' "$JMS_FILE")
echo "   ✅ Total de filas definidas: $TOTAL_QUEUES"
echo ""

# 3️⃣ Verifica se o container está ativo
echo "[2/4] Verificando status do container $CONTAINER_NAME..."
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  echo "   ❌ O container $CONTAINER_NAME não está em execução."
  echo "   Inicie-o com ./fase3-subida-jboss.sh e tente novamente."
  exit 1
else
  echo "   ✅ Container ativo."
fi

# 4️⃣ Consulta o JNDI dentro do JBoss
echo "[3/4] Verificando registros JNDI dentro do JBoss..."
docker exec -it "$CONTAINER_NAME" bash -c "
  cd /opt/jboss-5.1.0.GA/bin
  ./twiddle.sh query 'jboss.mq.destination:*' | grep 'service=Queue' || echo 'Nenhuma fila JMS registrada.'
" 2>/dev/null

# 5️⃣ Resumo final
echo ""
echo "[4/4] Resumo:"
echo "   - Se todas as filas aparecerem acima, o JMS está OK."
echo "   - Caso alguma não apareça, revise o arquivo:"
echo "       $JMS_FILE"
echo "   - Ou execute novamente: ./fase1-configuracao.sh"
echo "=========================================================="
echo "   ✅ Verificação concluída."
echo "=========================================================="
