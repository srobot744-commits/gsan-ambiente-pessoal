#!/bin/bash
# ==========================================================
# SCRIPT: Fase 1 - Configuração do JBoss 5 para GSAN
# VERSÃO: 62 (atualizada em 2025-11-27)
# ==========================================================
# Funções:
# - Extrai arquivos base (log4j.xml, service.xml)
# - Gera e valida filas JMS (jbossmq-destinations-service.xml)
# - Inclui automaticamente filas adicionais BatchGerar*
# - Garante a presença de commons-lang.jar no diretório unificado de libs do JBoss
# - Cria backups e mantém /opt/gsan preservado
# ==========================================================

CONF_DIR="/root/docker/jboss5/conf"
SCRIPT_DIR="/root/scripts-gsan"
BASE_IMAGE="meu-jboss5-local"
CONTAINER_NAME="jboss-servidor"
JMS_FILE="$CONF_DIR/jbossmq-destinations-service.xml"

# Diretórios de libs / deploy
JBOSS_LIB_DIR="/root/docker/jboss5/jboss-files/lib"
DEPLOY_DIR="/root/docker/jboss5/deploy"
EAR_LIB_DIR="$DEPLOY_DIR/gcom.ear/lib"
WAR_LIB_DIR="$DEPLOY_DIR/gcom.ear/gcom.war/WEB-INF/lib"

echo "=========================================================="
echo "   INICIANDO FASE 1/3: CONFIGURAÇÃO DO JBOSS (V62)"
echo "=========================================================="

# 1️ Verificação de diretórios
echo "[1/9] Verificando estrutura de diretórios..."
for dir in "$CONF_DIR" "$SCRIPT_DIR"; do
  if [ ! -d "$dir" ]; then
    echo "   ❌ Diretório ausente: $dir"
    echo "   Corrija antes de continuar."
    exit 1
  fi
done
echo "   ✅ Estrutura validada."

# 2️ Extração dos arquivos base
echo "[2/9] Extraindo arquivos de configuração do container base..."
docker run --rm "$BASE_IMAGE" cat /opt/jboss-5.1.0.GA/server/default/conf/jboss-log4j.xml > "$CONF_DIR/jboss-log4j.xml"
docker run --rm "$BASE_IMAGE" cat /opt/jboss-5.1.0.GA/server/default/conf/jboss-service.xml > "$CONF_DIR/jboss-service.xml"
if [ ! -s "$CONF_DIR/jboss-log4j.xml" ] || [ ! -s "$CONF_DIR/jboss-service.xml" ]; then
  echo "   ❌ Falha ao extrair arquivos do container base."
  exit 1
fi
echo "   ✅ Arquivos base extraídos."

# 3️ Inserção automática do parâmetro Threshold no log4j.xml
echo "[3/9] Verificando parâmetro <Threshold>..."
if ! grep -q '<param name="Threshold"' "$CONF_DIR/jboss-log4j.xml"; then
  sed -i '/<param name="Append" value="false"\/>/a\    <param name="Threshold" value="INFO" />' "$CONF_DIR/jboss-log4j.xml"
  echo "   ✅ Parâmetro <Threshold> inserido."
else
  echo "   ✅ Parâmetro <Threshold> já existente."
fi

# 4️ Geração de filas JMS (principais + complementares)
echo "[4/9] Gerando definições JMS..."
cat > "$JMS_FILE" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<server>
  <mbean code="org.jboss.mq.server.jmx.Queue"
         name="jboss.mq.destination:name=queue/DLQ,service=Queue">
    <attribute name="JNDIName">queue/DLQ</attribute>
    <depends optional-attribute-name="DestinationManager">jboss.mq:service=DestinationManager</depends>
  </mbean>
EOF

# Filas padrão (já estáveis)
QUEUES=(
  BatchProgramacaoAutoRoteiroAcompServicoMDB
  BatchRegistrarBoletosMDB
  BatchSuspenderImovelEmProgramaEspecialMDB
  BatchRetificarConjuntoContaConsumosMDB
  BatchRetirarImovelTarifaSocialMDB
  BatchRelatorioContasBaixadasContabilmenteMDB
  BatchReligarImoveisCortadosComConsumoRealMDB
  BatchSuspenderLeituraParaImovelComHidrometroRetiradoMDB
  BatchSuspenderLeituraParaImovelComConsumoRealNaoSuperiorA10MDB
  BatchVerificarFaturamentoImoveisCortadosMDB
)

# Filas adicionais detectadas nos logs (faltantes)
EXTRA_QUEUES=(
  BatchGerarResumoDocumentosAReceberMDB
  BatchGerarResumoDiarioNegativacaoMDB
  BatchGerarResumoDevedoresDuvidososMDB
  BatchGerarResumoConsumoAguaMDB
  BatchGerarResumoColetaEsgotoPorAnoMDB
  BatchGerarResumoColetaEsgotoMDB
  BatchGerarResumoArrecadacaoPorAnoMDB
  BatchGerarResumoAnormalidadesMDB
  BatchGerarResumoAcoesCobrancaEventualMDB
  BatchGerarResumoAcoesCobrancaCronogramaMDB
  BatchGerarResumoAcoesCobrancaCronogramaEncerrarOSMDB
  BatchGerarRAOSAnormalidadeConsumoMDB
  BatchGerarPrescreverDebitosDeImoveisMDB
  BatchGerarNegociacaoContasCobrancaEmpresaMDB
  BatchGerarMovimentoRetornoNegativacaoMDB
  BatchGerarMovimentoHidrometroMDB
  BatchGerarMovimentoExtensaoContasCobrancaPorEmpresaMDB
  BatchGerarMovimentoExclusaoNegativacaoMDB
  BatchGerarMovimentoContasCobrancaPorEmpresaMDB
  BatchGerarLancamentosContabeisFaturamentoMDB
)

# Combinar ambas as listas
ALL_QUEUES=("${QUEUES[@]}" "${EXTRA_QUEUES[@]}")

for q in "${ALL_QUEUES[@]}"; do
  cat >> "$JMS_FILE" <<EOF
  <mbean code="org.jboss.mq.server.jmx.Queue"
         name="jboss.mq.destination:name=${q},service=Queue">
    <attribute name="JNDIName">${q}</attribute>
    <depends optional-attribute-name="DestinationManager">jboss.mq:service=DestinationManager</depends>
  </mbean>
EOF
done

echo "</server>" >> "$JMS_FILE"
echo "   ✅ Arquivo JMS gerado: $JMS_FILE"

# 5️ Backups
echo "[5/9] Criando backups..."
cp "$CONF_DIR/jboss-log4j.xml" "$SCRIPT_DIR/jboss-log4j.xml.bak"
cp "$CONF_DIR/jboss-service.xml" "$SCRIPT_DIR/jboss-service.xml.bak"
cp "$JMS_FILE" "$SCRIPT_DIR/jbossmq-destinations-service.xml.bak"
echo "   ✅ Backups salvos em $SCRIPT_DIR."

# 6️ Validação básica
echo "[6/9] Validando arquivos..."
if [ -s "$CONF_DIR/jboss-log4j.xml" ] && [ -s "$CONF_DIR/jboss-service.xml" ] && [ -s "$JMS_FILE" ]; then
  echo "   ✅ Arquivos de configuração válidos."
else
  echo "   ❌ Falha na geração dos arquivos de configuração."
  exit 1
fi

# 7️ Verificação de registro JMS no JNDI (automática)
echo "[7/9] Verificando se as filas JMS estão registradas..."
if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  RESULT=$(docker exec "$CONTAINER_NAME" bash -c "cd /opt/jboss-5.1.0.GA/bin && ./twiddle.sh query 'jboss.mq.destination:*' | grep 'service=Queue'" 2>/dev/null)
  if [ -z "$RESULT" ]; then
    echo "   ⚠️ Nenhuma fila JMS encontrada no JNDI. Recriando arquivo JMS..."
    cp "$SCRIPT_DIR/jbossmq-destinations-service.xml.bak" "$JMS_FILE"
    echo "   ✅ JMS reconstituído a partir do backup."
  else
    echo "   ✅ Filas JMS detectadas no servidor:"
    echo "$RESULT" | sed 's/^/      - /'
  fi
else
  echo "   ℹ️ Container $CONTAINER_NAME não está rodando — verificação JNDI ignorada."
  echo "   (Será validado automaticamente na Fase 3)"
fi

# 8️ Garantir commons-lang.jar no diretório unificado de libs do JBoss
echo "[8/9] Garantindo commons-lang.jar em $JBOSS_LIB_DIR..."

mkdir -p "$JBOSS_LIB_DIR"

if [ -f "$JBOSS_LIB_DIR/commons-lang.jar" ]; then
  echo "   ✅ commons-lang.jar já presente em $JBOSS_LIB_DIR"
else
  if [ -f "$EAR_LIB_DIR/commons-lang.jar" ]; then
    echo "   → Copiando commons-lang.jar do EAR para $JBOSS_LIB_DIR..."
    cp "$EAR_LIB_DIR/commons-lang.jar" "$JBOSS_LIB_DIR/"
    echo "   ✅ commons-lang.jar copiado do EAR."
  elif [ -f "$WAR_LIB_DIR/commons-lang.jar" ]; then
    echo "   → Copiando commons-lang.jar do WAR para $JBOSS_LIB_DIR..."
    cp "$WAR_LIB_DIR/commons-lang.jar" "$JBOSS_LIB_DIR/"
    echo "   ✅ commons-lang.jar copiado do WAR."
  else
    echo "   ⚠ commons-lang.jar não encontrado em:"
    echo "      - $EAR_LIB_DIR"
    echo "      - $WAR_LIB_DIR"
    echo "   Se este for o primeiro build completo, o EAR/WAR pode ainda não existir."
    echo "   Após a Fase 2 (compilação) verifique novamente se o jar foi unificado."
  fi
fi

# 9️ Conclusão
echo "[9/9] Finalizando..."
echo "=========================================================="
echo "   ✅ FASE 1 CONCLUÍDA COM SUCESSO (JBoss Configurado)"
echo "   Arquivos prontos em: $CONF_DIR"
echo "=========================================================="
