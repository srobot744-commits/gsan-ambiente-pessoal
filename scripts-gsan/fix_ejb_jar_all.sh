#!/bin/bash
# ==========================================================
# SCRIPT: Correção Consolidada de EJB-JAR.XMLs do GSAN
# Função: Corrigir todos os módulos EJB problemáticos
# Autor: ChatGPT + Cláudio Pontes da Silva
# Versão: 3.0 (2025-11-09)
# ==========================================================

GSAN_DIR="/opt/gsan/descriptors"
LOG_DIR="/root/scripts-gsan/logs"
LOG_FILE="$LOG_DIR/fix_ejb_all_$(date +%Y-%m-%d-%H%M).log"
mkdir -p "$LOG_DIR"

echo "=========================================================="
echo "  INICIANDO CORREÇÃO CONSOLIDADA DOS EJB-JAR.XML"
echo "==========================================================" | tee -a "$LOG_FILE"

# 🔹 Lista dos módulos a corrigir
MODULES=(
  "batchGerarResumoIndicadoresComercializacao"
  "batchGerarArquivoTextoContasCobrancaEmpresa"
  "batchAtualizarLigacaoAguaLigadoAnaliseParaLigado"
  "batchGerarResumoAcoesCobrancaCronogramaEncerrarOS"
  "batchEncerrarComandoOSSeletivaInspecaoAnormalidade"
  "batchGerarDadosArquivoAcompanhamentoServico"
  "batchInserirResumoAcoesCobrancaCronograma"
  "batchEmitirOrdemDeFiscalizacao"
  "batchGerarResumoLigacoesEconomiasPorAno"
  "batchGerarTxtOsInspecaoAnormalidade"
  "batchProgramacaoAutoRoteiroAcompServico"
  "batchGerarResumoAcoesCobrancaCronograma"
  "batchGerarResumoDiarioNegativacao"
  "batchAtualizarCodigoDebitoAutomatico"
)

# 🔹 Estrutura XML padrão
generate_xml() {
cat <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE ejb-jar PUBLIC "-//Sun Microsystems, Inc.//DTD Enterprise JavaBeans 2.0//EN"
 "http://java.sun.com/dtd/ejb-jar_2_0.dtd">
<ejb-jar>
  <display-name>__EJB_NAME__</display-name>
  <enterprise-beans>
    <session>
      <ejb-name>__EJB_NAME__</ejb-name>
      <local-home>gcom.batch.__EJB_NAME__LocalHome</local-home>
      <local>gcom.batch.__EJB_NAME__Local</local>
      <ejb-class>gcom.batch.__EJB_NAME__</ejb-class>
      <session-type>Stateless</session-type>
      <transaction-type>Container</transaction-type>
    </session>
  </enterprise-beans>
  <assembly-descriptor>
    <container-transaction>
      <method>
        <ejb-name>__EJB_NAME__</ejb-name>
        <method-name>*</method-name>
      </method>
      <trans-attribute>Required</trans-attribute>
    </container-transaction>
  </assembly-descriptor>
</ejb-jar>
EOF
}

# 🔹 Loop pelos módulos
for module in "${MODULES[@]}"; do
  TARGET_XML="$GSAN_DIR/$module/META-INF/ejb-jar.xml"
  if [ -f "$TARGET_XML" ]; then
    BACKUP="${TARGET_XML}.bak_$(date +%Y%m%d%H%M%S)"
    cp "$TARGET_XML" "$BACKUP"
    echo "🧩 Corrigindo módulo: $module" | tee -a "$LOG_FILE"
    generate_xml | sed "s/__EJB_NAME__/${module}/g" > "$TARGET_XML"
    echo "   ✅ Corrigido e salvo: $TARGET_XML" | tee -a "$LOG_FILE"
  else
    echo "   ⚠️ Arquivo ausente: $TARGET_XML" | tee -a "$LOG_FILE"
  fi
done

# 🔹 Correção específica: ControladorAnaliseGeracaoContaGCOM
TARGET_ANALISE="$GSAN_DIR/batchAtualizarLigacaoAguaLigadoAnaliseParaLigado/META-INF/ejb-jar.xml"
if [ -f "$TARGET_ANALISE" ]; then
  echo "🔧 Ajuste específico: ControladorAnaliseGeracaoContaGCOM" | tee -a "$LOG_FILE"
  sed -i "s/__EJB_NAME__/ControladorAnaliseGeracaoContaGCOM/g" "$TARGET_ANALISE"
fi

echo "----------------------------------------------------------" | tee -a "$LOG_FILE"
echo "✅ Correção consolidada concluída. Log: $LOG_FILE" | tee -a "$LOG_FILE"
echo "=========================================================="
