#!/bin/bash
# ==========================================================
# SCRIPT: Pipeline Completo de Build e Deploy GSAN
# VERSÃO: 1.1 (2025-11-08)
# ==========================================================
# Executa automaticamente:
#  1️⃣ Limpeza profunda do ambiente (opcional)
#  2️⃣ Fase 1 - Configuração do JBoss
#  3️⃣ Fase 2 - Ajuste de XMLs
#  4️⃣ Fase 2 - Compilação do GSAN
#  5️⃣ Commit local automático (sem push)
#  6️⃣ Fase 3 - Subida do JBoss
#
# Uso:
#   bash pipeline-gsan.sh        → execução completa
#   bash pipeline-gsan.sh --fast → ignora limpeza profunda
# ==========================================================

SCRIPTS_DIR="/root/scripts-gsan"
LOG_FILE="$SCRIPTS_DIR/logs/pipeline_$(date +%Y%m%d-%H%M%S).log"
GSAN_DIR="/opt/gsan"

echo "=========================================================="
echo "         🚀 INICIANDO PIPELINE COMPLETO DO GSAN"
echo "=========================================================="
if [ "$1" == "--fast" ]; then
  echo "⚙️  MODO RÁPIDO ATIVADO: limpeza profunda será ignorada."
else
  echo "🧹  MODO COMPLETO: executando todas as fases (inclui limpeza profunda)."
fi
echo "Log em: $LOG_FILE"
echo "----------------------------------------------------------"
sleep 2

# Função auxiliar para execução com log
run_step() {
  local step_name="$1"
  local script_path="$2"

  echo "[ETAPA] $step_name"
  echo "----------------------------------------------------------" | tee -a "$LOG_FILE"
  if [ -x "$script_path" ]; then
    bash "$script_path" 2>&1 | tee -a "$LOG_FILE"
    if [ "${PIPESTATUS[0]}" -ne 0 ]; then
      echo "❌ Erro durante a etapa: $step_name" | tee -a "$LOG_FILE"
      exit 1
    fi
    echo "✅ Etapa concluída: $step_name" | tee -a "$LOG_FILE"
  else
    echo "❌ Script não encontrado ou sem permissão: $script_path" | tee -a "$LOG_FILE"
    exit 1
  fi
  echo "----------------------------------------------------------" | tee -a "$LOG_FILE"
  sleep 2
}

# 1️⃣ Limpeza profunda (opcional)
if [ "$1" != "--fast" ]; then
  run_step "Limpeza Profunda do Ambiente" "$SCRIPTS_DIR/limpeza-profunda.sh"
else
  echo "[INFO] Etapa de limpeza profunda ignorada (--fast ativado)." | tee -a "$LOG_FILE"
fi

# 2️⃣ Configuração do JBoss
run_step "Fase 1 - Configuração do JBoss" "$SCRIPTS_DIR/fase1-configuracao.sh"

# 3️⃣ Ajuste de XMLs
run_step "Fase 2 - Ajuste de XMLs" "$SCRIPTS_DIR/fase2_ajuste_xmls.sh"

# 4️⃣ Compilação do GSAN
run_step "Fase 2 - Compilação do GSAN" "$SCRIPTS_DIR/fase2-compilacao.sh"

# 5️⃣ Commit local automático
echo "[ETAPA] Commit Local de Alterações"
cd "$GSAN_DIR" || exit 1
if git status --porcelain | grep -q .; then
  git add .
  git commit -m "🧩 Atualização automática do pipeline GSAN - $(date '+%Y-%m-%d %H:%M:%S')" | tee -a "$LOG_FILE"
  echo "✅ Commit local realizado com sucesso." | tee -a "$LOG_FILE"
else
  echo "ℹ️ Nenhuma alteração detectada para commit." | tee -a "$LOG_FILE"
fi
echo "----------------------------------------------------------" | tee -a "$LOG_FILE"

# 6️⃣ Subida do JBoss
run_step "Fase 3 - Subida do JBoss" "$SCRIPTS_DIR/fase3-subida-jboss.sh"

# Finalização
echo "=========================================================="
echo "🎯 PIPELINE GSAN FINALIZADO COM SUCESSO!"
echo "Confira o log completo em: $LOG_FILE"
echo "=========================================================="
