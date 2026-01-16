#!/bin/bash
# ==========================================================
# SCRIPT: Fase 3 - Subida do JBoss com GSAN
# VERSÃO: 60 (consolidada - 2026-01-12)
# ==========================================================
# Funções:
# - Sobe o container JBoss com GSAN
# - Usa volumes para logs, deploy e configurações
# - Garante carregamento correto das filas JMS (via deploy)
# - Faz limpeza preventiva de classes duplicadas no WAR
#   - ControladorUtil* (WAR)                  -> mantém só no EJB
#   - SistemaParametro*.class (WAR)           -> mantém só no EJB
#   - Filtro.class / FiltroParametro.class    -> mantém só no EJB
#   - Pacote completo gcom.seguranca.acesso   -> mantém só no EJB
#   - HibernateUtil.class (WAR)               -> mantém só no EJB
#   - DbVersaoBase.class (WAR)                -> mantém só no EJB
#   - Empresa.class (WAR)                     -> mantém só no EJB
#   - TabelaColuna*.class (WAR)               -> mantém só no EJB  ✅ (NOVO)
#   - ControladorEndereco* (WAR)              -> mantém só no EJB  ✅ (NOVO - Inserir CEP)
# ==========================================================

CONF_DIR="/root/docker/jboss5/conf"
DEPLOY_DIR="/root/docker/jboss5/deploy"
LOG_DIR="/root/docker/jboss5/log"
REPORTS_DIR="/root/docker/gsan-reports"
LIB_DIR="/root/docker/jboss5/jboss-files/lib"

echo "=========================================================="
echo "       INICIANDO FASE 3/3: SUBIDA DO JBOSS (V60)"
echo "=========================================================="

# [1/7] Verificação de diretórios
echo "[1/7] Verificando diretórios necessários..."
for dir in "$CONF_DIR" "$DEPLOY_DIR" "$LOG_DIR" "$REPORTS_DIR" "$LIB_DIR"; do
  if [ ! -d "$dir" ]; then
    echo "   ❌ Diretório ausente: $dir"
    exit 1
  fi
done
echo "   ✅ Estrutura de diretórios validada."

# [2/7] Garantir que não exista container ativo
echo "[2/7] Garantindo que não exista container ativo..."
docker stop jboss-servidor &>/dev/null
docker rm jboss-servidor &>/dev/null
echo "   ✅ Nenhum container JBoss ativo."

# ==========================================================
# [ETAPA EXTRA] Limpeza preventiva de classes duplicadas no WAR
# Evita conflitos de classloader (LinkageError / VerifyError / NPE / Hibernate)
# ==========================================================

EAR_DIR="$DEPLOY_DIR/gcom.ear"
WAR_DIR="$EAR_DIR/gcom.war"
WAR_CLASSES_DIR="$WAR_DIR/WEB-INF/classes"
BACKUP_BASE="$EAR_DIR/backup-duplicados-$(date +%Y%m%d-%H%M%S)"


# ==========================================================
# Função util: mover lista de arquivos do WAR para backup
# Uso: mover_duplicados_war "Label" "path/relativo/no/WEB-INF/classes" ...
# ==========================================================
mover_duplicados_war() {
  local label="$1"; shift
  local backup="$BACKUP_BASE/$label"
  mkdir -p "$backup"

  for rel in "$@"; do
    local src="$WAR_CLASSES_DIR/$rel"
    if [ -f "$src" ]; then
      echo "[Fase 3] Movendo $rel -> $backup/"
      mv -v "$src" "$backup/" 2>/dev/null || mv -v "$src" "$backup/"
    fi
  done
}

echo "----------------------------------------------------------"
echo "[Fase 3] Limpando classes duplicadas no WAR..."
echo "          (ControladorUtil, SistemaParametro, Filtro/FiltroParametro,"
echo "           pacote completo seguranca.acesso,"
echo "           HibernateUtil, DbVersaoBase, Empresa,"
echo "           TabelaColuna, ControladorEndereco)"


# ==========================================================
# [CORREÇÃO DEFINITIVA] Unificar classes de TabelaAuxiliar (EJB)
# Evita:
# - ClassCastException Proxy cannot be cast to ControladorTabelaAuxiliarLocalHome
# - LinkageError loader constraint (TabelaAuxiliarAbstrata)
#
# Estratégia:
# 1) Criar JAR compartilhado em gcom.ear/lib com essas classes (classloader do EAR)
# 2) Remover as duplicadas do WAR e dos JARs:
#    - gcom.jar
#    - ControladorTabelaAuxiliarGCOM.jar
# ==========================================================

echo "----------------------------------------------------------"
echo "[Fase 3] Unificando classes EJB de TabelaAuxiliar (WAR/JARs -> EAR/lib)..."

if [ ! -d "$EAR_DIR" ]; then
  echo "[Fase 3] EAR não encontrado em $EAR_DIR. Pulando unificação de TabelaAuxiliar."
else
  mkdir -p "$BACKUP_BASE"
  mkdir -p "$EAR_DIR/lib"

  # Classes alvo (paths dentro do JAR)
  TA_CLASSES=(
    "gcom/util/tabelaauxiliar/ControladorTabelaAuxiliarHome.class"
    "gcom/util/tabelaauxiliar/ControladorTabelaAuxiliarLocal.class"
    "gcom/util/tabelaauxiliar/ControladorTabelaAuxiliarLocalHome.class"
    "gcom/util/tabelaauxiliar/ControladorTabelaAuxiliarRemote.class"
    "gcom/util/tabelaauxiliar/ControladorTabelaAuxiliarSEJB.class"
    "gcom/util/tabelaauxiliar/TabelaAuxiliarAbstrata.class"
  )

  # JARs onde hoje existem cópias
  JAR_GCOM="$EAR_DIR/gcom.jar"
  JAR_CTRL="$EAR_DIR/ControladorTabelaAuxiliarGCOM.jar"
  SHARED_JAR="$EAR_DIR/lib/gsan-shared-tabelaauxiliar.jar"

  # 0) Backup dos JARs antes de mexer
  mkdir -p "$BACKUP_BASE/jars"
  [ -f "$JAR_GCOM" ] && cp -av "$JAR_GCOM" "$BACKUP_BASE/jars/" 2>/dev/null
  [ -f "$JAR_CTRL" ] && cp -av "$JAR_CTRL" "$BACKUP_BASE/jars/" 2>/dev/null

  # 1) Tirar do WAR (se existir)
  if [ -d "$WAR_CLASSES_DIR/gcom/util/tabelaauxiliar" ]; then
    mkdir -p "$BACKUP_BASE/TabelaAuxiliar_WAR"
    for p in "${TA_CLASSES[@]}"; do
      f="$WAR_CLASSES_DIR/$p"
      if [ -f "$f" ]; then
        echo "[Fase 3] (WAR) Movendo $(basename "$f") -> $BACKUP_BASE/TabelaAuxiliar_WAR/"
        mv -v "$f" "$BACKUP_BASE/TabelaAuxiliar_WAR/" 2>/dev/null
      fi
    done
  fi

  # 2) Montar o JAR compartilhado (EAR/lib) com a primeira cópia encontrada
  TMP_DIR="/tmp/gsan_ta_shared_$$"
  rm -rf "$TMP_DIR"
  mkdir -p "$TMP_DIR"

  extract_one() {
    local jar="$1"
    local path="$2"
    if [ -f "$jar" ] && jar tf "$jar" | grep -qx "$path"; then
      ( cd "$TMP_DIR" && jar xf "$jar" "$path" ) 2>/dev/null
      return 0
    fi
    return 1
  }

  for p in "${TA_CLASSES[@]}"; do
    # tenta extrair do gcom.jar, senão do ControladorTabelaAuxiliarGCOM.jar
    if extract_one "$JAR_GCOM" "$p"; then
      echo "[Fase 3] (SHARED) Extraído de gcom.jar: $p"
    elif extract_one "$JAR_CTRL" "$p"; then
      echo "[Fase 3] (SHARED) Extraído de ControladorTabelaAuxiliarGCOM.jar: $p"
    else
      echo "[Fase 3] (SHARED) ATENÇÃO: não achei $p em nenhum JAR (vou ignorar)."
    fi
  done

  if find "$TMP_DIR/gcom/util/tabelaauxiliar" -type f -name "*.class" >/dev/null 2>&1; then
    rm -f "$SHARED_JAR"
    ( cd "$TMP_DIR" && jar cf "$SHARED_JAR" gcom/util/tabelaauxiliar/*.class ) 2>/dev/null
    echo "[Fase 3] (SHARED) Criado: $SHARED_JAR"
  else
    echo "[Fase 3] (SHARED) Nenhuma classe extraída. Não criei o JAR compartilhado."
  fi

  # 3) Remover as duplicadas dos JARs (precisa do 'zip' para deletar entradas)
  if command -v zip >/dev/null 2>&1; then
    for jarfile in "$JAR_GCOM" "$JAR_CTRL"; do
      [ -f "$jarfile" ] || continue
      echo "[Fase 3] Limpando duplicadas dentro de: $jarfile"
      for p in "${TA_CLASSES[@]}"; do
        # zip -d retorna erro se não existir; por isso silenciamos
        zip -dq "$jarfile" "$p" 2>/dev/null || true
      done
    done
    echo "[Fase 3] (OK) Duplicadas removidas dos JARs (gcom.jar / ControladorTabelaAuxiliarGCOM.jar)."
  else
    echo "[Fase 3] ERRO: comando 'zip' não encontrado. Não consigo remover classes dos JARs."
    echo "[Fase 3] Instale com: apt-get update && apt-get install -y zip"
    echo "[Fase 3] (IMPORTANTE) Sem remover duplicadas dos JARs, o ClassCast pode continuar."
    exit 1
  fi

  rm -rf "$TMP_DIR"
fi

echo "[Fase 3] Unificação de TabelaAuxiliar concluída."
echo "----------------------------------------------------------"


if [ ! -d "$WAR_CLASSES_DIR" ]; then
  echo "[Fase 3] Diretório $WAR_CLASSES_DIR não existe. Provavelmente o EAR não está expandido."
  echo "[Fase 3] Pulando limpeza de classes duplicadas no WAR."
else
  mkdir -p "$BACKUP_BASE"

  # 1) ControladorUtil* no WAR (gcom/util)
  CONTROLADORUTIL_DIR="$WAR_CLASSES_DIR/gcom/util"

  if [ -d "$CONTROLADORUTIL_DIR" ]; then
    echo "[Fase 3] Pasta encontrada: $CONTROLADORUTIL_DIR"
    BACKUP_CONTROLADORUTIL_DIR="$BACKUP_BASE/ControladorUtil"
    mkdir -p "$BACKUP_CONTROLADORUTIL_DIR"

    for cls in \
      ControladorUtilHome.class \
      ControladorUtilLocalHome.class \
      ControladorUtilRemote.class \
      ControladorUtilLocal.class \
      ControladorUtilSEJB.class
    do
      if [ -f "$CONTROLADORUTIL_DIR/$cls" ]; then
        echo "[Fase 3] Movendo $cls para $BACKUP_CONTROLADORUTIL_DIR/"
        mv "$CONTROLADORUTIL_DIR/$cls" "$BACKUP_CONTROLADORUTIL_DIR/" 2>/dev/null
      fi
    done
  else
    echo "[Fase 3] Diretório $CONTROLADORUTIL_DIR não existe, nada a limpar para ControladorUtil."
  fi

  # 2) SistemaParametro*.class do WAR (gcom/cadastro/sistemaparametro)
  SISTEMA_PARAM_DIR="$WAR_CLASSES_DIR/gcom/cadastro/sistemaparametro"

  if [ -d "$SISTEMA_PARAM_DIR" ]; then
    echo "[Fase 3] Pasta encontrada: $SISTEMA_PARAM_DIR"
    BACKUP_SISTEMA_PARAM_DIR="$BACKUP_BASE/SistemaParametro"
    mkdir -p "$BACKUP_SISTEMA_PARAM_DIR"

    if ls "$SISTEMA_PARAM_DIR"/SistemaParametro*.class >/dev/null 2>&1; then
      echo "[Fase 3] Movendo SistemaParametro*.class para $BACKUP_SISTEMA_PARAM_DIR/"
      mv "$SISTEMA_PARAM_DIR"/SistemaParametro*.class "$BACKUP_SISTEMA_PARAM_DIR/" 2>/dev/null
    else
      echo "[Fase 3] Nenhuma SistemaParametro*.class encontrada para mover (OK)."
    fi
  else
    echo "[Fase 3] Diretório $SISTEMA_PARAM_DIR não existe, nada a limpar para SistemaParametro."
  fi

  # 3) Filtro/FiltroParametro do WAR (gcom/util/filtro)
  FILTRO_DIR="$WAR_CLASSES_DIR/gcom/util/filtro"

  if [ -d "$FILTRO_DIR" ]; then
    echo "[Fase 3] Pasta encontrada (Filtro/FiltroParametro): $FILTRO_DIR"
    BACKUP_FILTRO_DIR="$BACKUP_BASE/FiltroClasses"
    mkdir -p "$BACKUP_FILTRO_DIR"

    for cls in \
      Filtro.class \
      FiltroParametro.class
    do
      if [ -f "$FILTRO_DIR/$cls" ]; then
        echo "[Fase 3] Movendo $cls para $BACKUP_FILTRO_DIR/"
        mv "$FILTRO_DIR/$cls" "$BACKUP_FILTRO_DIR"/ 2>/dev/null
      fi
    done
  else
    echo "[Fase 3] Diretório $FILTRO_DIR não existe, nada a limpar para Filtro/FiltroParametro."
  fi

  # 4) Pacote completo de segurança/acesso no WAR (gcom/seguranca/acesso)
  ACESSO_DIR="$WAR_CLASSES_DIR/gcom/seguranca/acesso"

  if [ -d "$ACESSO_DIR" ]; then
    echo "[Fase 3] Pasta encontrada (pacote completo seguranca.acesso): $ACESSO_DIR"
    BACKUP_ACESSO_DIR="$BACKUP_BASE/seguranca_acesso_war"
    mkdir -p "$BACKUP_ACESSO_DIR"

    echo "[Fase 3] Movendo diretório inteiro gcom/seguranca/acesso para $BACKUP_ACESSO_DIR/"
    mv "$ACESSO_DIR" "$BACKUP_ACESSO_DIR"/ 2>/dev/null
  else
    echo "[Fase 3] Diretório $ACESSO_DIR não existe, nada a limpar para seguranca.acesso."
  fi

  # 4.5) TabelaColuna* do WAR (gcom/seguranca/transacao) -> mantém só no EJB (gcom.jar)
  TRANSACAO_DIR="$WAR_CLASSES_DIR/gcom/seguranca/transacao"

  if [ -d "$TRANSACAO_DIR" ]; then
    echo "[Fase 3] Pasta encontrada (seguranca.transacao): $TRANSACAO_DIR"
    BACKUP_TRANSACAO_DIR="$BACKUP_BASE/seguranca_transacao_war"
    mkdir -p "$BACKUP_TRANSACAO_DIR"

    for cls in \
      TabelaColuna.class \
      TabelaColunaAtualizacaoCadastral.class
    do
      if [ -f "$TRANSACAO_DIR/$cls" ]; then
        echo "[Fase 3] Movendo $cls para $BACKUP_TRANSACAO_DIR/"
        mv "$TRANSACAO_DIR/$cls" "$BACKUP_TRANSACAO_DIR/" 2>/dev/null
      else
        echo "[Fase 3] $cls não encontrado no WAR (OK)."
      fi
    done
  else
    echo "[Fase 3] Diretório $TRANSACAO_DIR não existe, nada a limpar para seguranca.transacao."
  fi

  # 5) HibernateUtil.class do WAR (gcom/util)
  HIBERNATEUTIL_DIR="$WAR_CLASSES_DIR/gcom/util"

  if [ -d "$HIBERNATEUTIL_DIR" ]; then
    echo "[Fase 3] Pasta encontrada (HibernateUtil): $HIBERNATEUTIL_DIR"
    BACKUP_HIBERNATE_DIR="$BACKUP_BASE/HibernateUtil"
    mkdir -p "$BACKUP_HIBERNATE_DIR"

    if [ -f "$HIBERNATEUTIL_DIR/HibernateUtil.class" ]; then
      echo "[Fase 3] Movendo HibernateUtil.class para $BACKUP_HIBERNATE_DIR/"
      mv "$HIBERNATEUTIL_DIR/HibernateUtil.class" "$BACKUP_HIBERNATE_DIR"/ 2>/dev/null
    else
      echo "[Fase 3] HibernateUtil.class não encontrado no WAR (OK)."
    fi
  else
    echo "[Fase 3] Diretório $HIBERNATEUTIL_DIR não existe, nada a limpar para HibernateUtil."
  fi

  # 6) DbVersaoBase.class do WAR (gcom/cadastro)
  DBVERSAO_DIR="$WAR_CLASSES_DIR/gcom/cadastro"

  if [ -d "$DBVERSAO_DIR" ]; then
    echo "[Fase 3] Pasta encontrada (DbVersaoBase): $DBVERSAO_DIR"
    BACKUP_DBVERSAO_DIR="$BACKUP_BASE/DbVersaoBase"
    mkdir -p "$BACKUP_DBVERSAO_DIR"

    if [ -f "$DBVERSAO_DIR/DbVersaoBase.class" ]; then
      echo "[Fase 3] Movendo DbVersaoBase.class para $BACKUP_DBVERSAO_DIR/"
      mv "$DBVERSAO_DIR/DbVersaoBase.class" "$BACKUP_DBVERSAO_DIR"/ 2>/dev/null
    else
      echo "[Fase 3] DbVersaoBase.class não encontrado no WAR (OK)."
    fi
  else
    echo "[Fase 3] Diretório $DBVERSAO_DIR não existe, nada a limpar para DbVersaoBase."
  fi

  # 7) Empresa.class do WAR (gcom/cadastro/empresa)
  EMPRESA_DIR="$WAR_CLASSES_DIR/gcom/cadastro/empresa"
  EMPRESA_CLASS="$EMPRESA_DIR/Empresa.class"

  if [ -d "$EMPRESA_DIR" ]; then
    echo "[Fase 3] Pasta encontrada (Empresa): $EMPRESA_DIR"
    BACKUP_EMPRESA_DIR="$BACKUP_BASE/Empresa"
    mkdir -p "$BACKUP_EMPRESA_DIR"

    if [ -f "$EMPRESA_CLASS" ]; then
      echo "[Fase 3] Movendo Empresa.class para $BACKUP_EMPRESA_DIR/"
      mv "$EMPRESA_CLASS" "$BACKUP_EMPRESA_DIR"/ 2>/dev/null
    else
      echo "[Fase 3] Empresa.class não encontrado no WAR (OK)."
    fi
  else
    echo "[Fase 3] Diretório $EMPRESA_DIR não existe, nada a limpar para Empresa."
  fi

  # ==========================================================
  # 8) TabelaColuna*.class do WAR (gcom/seguranca/transacao)  ✅ NOVO
  # Corrige: expected type TabelaColuna, actual value TabelaColuna_$$_javassist_*
  # ==========================================================
  TABELA_COLUNA_DIR="$WAR_CLASSES_DIR/gcom/seguranca/transacao"
  if [ -d "$TABELA_COLUNA_DIR" ]; then
    echo "[Fase 3] Pasta encontrada (TabelaColuna*): $TABELA_COLUNA_DIR"
    BACKUP_TABELA_COLUNA_DIR="$BACKUP_BASE/TabelaColuna"
    mkdir -p "$BACKUP_TABELA_COLUNA_DIR"

    if ls "$TABELA_COLUNA_DIR"/TabelaColuna*.class >/dev/null 2>&1; then
      echo "[Fase 3] Movendo TabelaColuna*.class para $BACKUP_TABELA_COLUNA_DIR/"
      mv "$TABELA_COLUNA_DIR"/TabelaColuna*.class "$BACKUP_TABELA_COLUNA_DIR/" 2>/dev/null
    else
      echo "[Fase 3] Nenhuma TabelaColuna*.class encontrada para mover (OK)."
    fi
  else
    echo "[Fase 3] Diretório $TABELA_COLUNA_DIR não existe, nada a limpar para TabelaColuna*."
  fi

  # ==========================================================
  # 9) ControladorEndereco* no WAR (gcom/cadastro/endereco) ✅ NOVO (Inserir CEP)
  # Evita: Proxy cannot be cast to ControladorEnderecoLocalHome
  # ==========================================================
  ENDERECO_DIR="$WAR_CLASSES_DIR/gcom/cadastro/endereco"
  if [ -d "$ENDERECO_DIR" ]; then
    echo "[Fase 3] Pasta encontrada (ControladorEndereco*): $ENDERECO_DIR"
    BACKUP_ENDERECO_DIR="$BACKUP_BASE/ControladorEndereco"
    mkdir -p "$BACKUP_ENDERECO_DIR"

    if ls "$ENDERECO_DIR"/ControladorEndereco*.class >/dev/null 2>&1; then
      echo "[Fase 3] Movendo ControladorEndereco*.class para $BACKUP_ENDERECO_DIR/"
      mv "$ENDERECO_DIR"/ControladorEndereco*.class "$BACKUP_ENDERECO_DIR/" 2>/dev/null
    else
      echo "[Fase 3] Nenhuma ControladorEndereco*.class encontrada para mover (OK)."
    fi
  else
    echo "[Fase 3] Diretório $ENDERECO_DIR não existe, nada a limpar para ControladorEndereco*."
  fi
fi


  # ==========================================================
  # 10) ControladorPermissaoEspecial* no WAR (gcom/seguranca) ✅ (Certidão Negativa)
  # Evita: ClassCastException Proxy cannot be cast to ControladorPermissaoEspecialLocalHome
  # ==========================================================
  mover_duplicados_war "ControladorPermissaoEspecial" \
    "gcom/seguranca/ControladorPermissaoEspecialLocalHome.class" \
    "gcom/seguranca/ControladorPermissaoEspecialLocal.class" \
    "gcom/seguranca/ControladorPermissaoEspecialSEJB.class"

  # 11) ENTIDADES Hibernate duplicadas no WAR ✅ (evita VerifyError/Javassist Enhancement failed)
  # Observação: essas classes também existem dentro do gcom.jar (no EAR). No WAR elas quebram proxy do Hibernate.
  mover_duplicados_war "EntidadesHibernate" \
    "gcom/arrecadacao/banco/Banco.class" \
    "gcom/arrecadacao/banco/Banco_.class" \
    "gcom/atendimentopublico/ligacaoesgoto/LigacaoEsgotoCaixaInspecao.class" \
    "gcom/atendimentopublico/ligacaoesgoto/LigacaoEsgotoCaixaInspecao_.class" \
    "gcom/atendimentopublico/ligacaoesgoto/LigacaoEsgotoDestinoAguasPluviais.class" \
    "gcom/atendimentopublico/ligacaoesgoto/LigacaoEsgotoDestinoAguasPluviais_.class" \
    "gcom/atendimentopublico/ligacaoesgoto/LigacaoEsgotoDestinoDejetos.class" \
    "gcom/atendimentopublico/ligacaoesgoto/LigacaoEsgotoDestinoDejetos_.class" \
    "gcom/atendimentopublico/ligacaoesgoto/LigacaoEsgotoEsgotamento.class" \
    "gcom/atendimentopublico/ligacaoesgoto/LigacaoEsgotoEsgotamento_.class" \
    "gcom/atendimentopublico/LigacaoOrigem.class" \
    "gcom/atendimentopublico/LigacaoOrigem_.class" \
    "gcom/atendimentopublico/ordemservico/EquipamentosEspeciais.class" \
    "gcom/atendimentopublico/ordemservico/EquipamentosEspeciais_.class" \
    "gcom/atendimentopublico/ordemservico/Material.class" \
    "gcom/atendimentopublico/ordemservico/Material_.class" \
    "gcom/cadastro/dadocensitario/IbgeSetorCensitario.class" \
    "gcom/cadastro/dadocensitario/IbgeSetorCensitario_.class" \
    "gcom/cadastro/endereco/LogradouroTipo.class" \
    "gcom/cadastro/endereco/LogradouroTipo_.class" \
    "gcom/cadastro/geografico/RegiaoDesenvolvimento.class" \
    "gcom/cadastro/geografico/RegiaoDesenvolvimento_.class" \
    "gcom/cadastro/imovel/AreaConstruidaFaixa.class" \
    "gcom/cadastro/imovel/AreaConstruidaFaixa_.class" \
    "gcom/cadastro/imovel/ImovelTipoCobertura.class" \
    "gcom/cadastro/imovel/ImovelTipoCobertura_.class" \
    "gcom/cadastro/imovel/ImovelTipoConstrucao.class" \
    "gcom/cadastro/imovel/ImovelTipoConstrucao_.class" \
    "gcom/cadastro/imovel/ImovelTipoHabitacao.class" \
    "gcom/cadastro/imovel/ImovelTipoHabitacao_.class" \
    "gcom/cadastro/imovel/ImovelTipoOcupante.class" \
    "gcom/cadastro/imovel/ImovelTipoOcupante_.class" \
    "gcom/cadastro/imovel/ImovelTipoPropriedade.class" \
    "gcom/cadastro/imovel/ImovelTipoPropriedade_.class" \
    "gcom/cadastro/imovel/PiscinaVolumeFaixa.class" \
    "gcom/cadastro/imovel/PiscinaVolumeFaixa_.class" \
    "gcom/cadastro/imovel/ReservatorioVolumeFaixa.class" \
    "gcom/cadastro/imovel/ReservatorioVolumeFaixa_.class" \
    "gcom/cadastro/localidade/QuadraPerfil.class" \
    "gcom/cadastro/localidade/QuadraPerfil_.class" \
    "gcom/faturamento/conta/ContaMotivoRetificacao.class" \
    "gcom/faturamento/conta/ContaMotivoRetificacao_.class" \
    "gcom/micromedicao/hidrometro/HidrometroLocalArmazenagem.class" \
    "gcom/micromedicao/hidrometro/HidrometroLocalArmazenagem_.class" \
    "gcom/micromedicao/hidrometro/HidrometroRelojoaria.class" \
    "gcom/micromedicao/hidrometro/HidrometroRelojoaria_.class" \
    "gcom/operacional/FonteCaptacao.class" \
    "gcom/operacional/FonteCaptacao_.class" \
    "gcom/operacional/SetorAbastecimento.class" \
    "gcom/operacional/SetorAbastecimento_.class" \
    "gcom/operacional/SistemaAbastecimento.class" \
    "gcom/operacional/SistemaAbastecimento_.class" \
    "gcom/operacional/SistemaEsgotoTratamentoTipo.class" \
    "gcom/operacional/SistemaEsgotoTratamentoTipo_.class" \
    "gcom/operacional/TipoCaptacao.class" \
    "gcom/operacional/TipoCaptacao_.class" \
    "gcom/operacional/ZonaAbastecimento.class" \
    "gcom/operacional/ZonaAbastecimento_.class" \
    "gcom/seguranca/transacao/AlteracaoTipo.class" \
    "gcom/seguranca/transacao/AlteracaoTipo_.class" \
    "gcom/seguranca/transacao/Tabela.class" \
    "gcom/seguranca/transacao/Tabela_.class"

  # 11) Entidades Hibernate duplicadas no WAR ✅
  # Evita: VerifyError / Javassist Enhancement failed (proxy factory do Hibernate)
  mover_duplicados_war "EntidadesHibernateDuplicadas" \
    "gcom/arrecadacao/banco/Banco.class" \
    "gcom/arrecadacao/banco/Banco_.class" \
    "gcom/atendimentopublico/ligacaoesgoto/LigacaoEsgotoCaixaInspecao.class" \
    "gcom/atendimentopublico/ligacaoesgoto/LigacaoEsgotoCaixaInspecao_.class" \
    "gcom/atendimentopublico/ligacaoesgoto/LigacaoEsgotoDestinoAguasPluviais.class" \
    "gcom/atendimentopublico/ligacaoesgoto/LigacaoEsgotoDestinoAguasPluviais_.class" \
    "gcom/atendimentopublico/ligacaoesgoto/LigacaoEsgotoDestinoDejetos.class" \
    "gcom/atendimentopublico/ligacaoesgoto/LigacaoEsgotoDestinoDejetos_.class" \
    "gcom/atendimentopublico/ligacaoesgoto/LigacaoEsgotoEsgotamento.class" \
    "gcom/atendimentopublico/ligacaoesgoto/LigacaoEsgotoEsgotamento_.class" \
    "gcom/atendimentopublico/LigacaoOrigem.class" \
    "gcom/atendimentopublico/LigacaoOrigem_.class" \
    "gcom/atendimentopublico/ordemservico/EquipamentosEspeciais.class" \
    "gcom/atendimentopublico/ordemservico/EquipamentosEspeciais_.class" \
    "gcom/atendimentopublico/ordemservico/Material.class" \
    "gcom/atendimentopublico/ordemservico/Material_.class" \
    "gcom/cadastro/dadocensitario/IbgeSetorCensitario.class" \
    "gcom/cadastro/dadocensitario/IbgeSetorCensitario_.class" \
    "gcom/cadastro/endereco/LogradouroTipo.class" \
    "gcom/cadastro/endereco/LogradouroTipo_.class" \
    "gcom/cadastro/geografico/RegiaoDesenvolvimento.class" \
    "gcom/cadastro/geografico/RegiaoDesenvolvimento_.class" \
    "gcom/cadastro/imovel/AreaConstruidaFaixa.class" \
    "gcom/cadastro/imovel/AreaConstruidaFaixa_.class" \
    "gcom/cadastro/imovel/ImovelTipoCobertura.class" \
    "gcom/cadastro/imovel/ImovelTipoCobertura_.class" \
    "gcom/cadastro/imovel/ImovelTipoConstrucao.class" \
    "gcom/cadastro/imovel/ImovelTipoConstrucao_.class" \
    "gcom/cadastro/imovel/ImovelTipoHabitacao.class" \
    "gcom/cadastro/imovel/ImovelTipoHabitacao_.class" \
    "gcom/cadastro/imovel/ImovelTipoOcupante.class" \
    "gcom/cadastro/imovel/ImovelTipoOcupante_.class" \
    "gcom/cadastro/imovel/ImovelTipoPropriedade.class" \
    "gcom/cadastro/imovel/ImovelTipoPropriedade_.class" \
    "gcom/cadastro/imovel/PiscinaVolumeFaixa.class" \
    "gcom/cadastro/imovel/PiscinaVolumeFaixa_.class" \
    "gcom/cadastro/imovel/ReservatorioVolumeFaixa.class" \
    "gcom/cadastro/imovel/ReservatorioVolumeFaixa_.class" \
    "gcom/cadastro/localidade/QuadraPerfil.class" \
    "gcom/cadastro/localidade/QuadraPerfil_.class" \
    "gcom/faturamento/conta/ContaMotivoRetificacao.class" \
    "gcom/faturamento/conta/ContaMotivoRetificacao_.class" \
    "gcom/micromedicao/hidrometro/HidrometroLocalArmazenagem.class" \
    "gcom/micromedicao/hidrometro/HidrometroLocalArmazenagem_.class" \
    "gcom/micromedicao/hidrometro/HidrometroRelojoaria.class" \
    "gcom/micromedicao/hidrometro/HidrometroRelojoaria_.class" \
    "gcom/operacional/FonteCaptacao.class" \
    "gcom/operacional/FonteCaptacao_.class" \
    "gcom/operacional/SetorAbastecimento.class" \
    "gcom/operacional/SetorAbastecimento_.class" \
    "gcom/operacional/SistemaAbastecimento.class" \
    "gcom/operacional/SistemaAbastecimento_.class" \
    "gcom/operacional/SistemaEsgotoTratamentoTipo.class" \
    "gcom/operacional/SistemaEsgotoTratamentoTipo_.class" \
    "gcom/operacional/TipoCaptacao.class" \
    "gcom/operacional/TipoCaptacao_.class" \
    "gcom/operacional/ZonaAbastecimento.class" \
    "gcom/operacional/ZonaAbastecimento_.class" \
    "gcom/seguranca/transacao/AlteracaoTipo.class" \
    "gcom/seguranca/transacao/AlteracaoTipo_.class" \
    "gcom/seguranca/transacao/Tabela.class" \
    "gcom/seguranca/transacao/Tabela_.class"



  # XX) Entidades Hibernate com OperacaoEfetuada/Usuario* no WAR ❌
  # Evita: VerifyError ... Javassist Enhancement failed ... Illegal use of nonvirtual function call
  mover_duplicados_war "Entidades_OperacaoEfetuada" \
    "gcom/atendimentopublico/ligacaoesgoto/LigacaoEsgotoDestinoDejetos.class" \
    "gcom/cadastro/imovel/ImovelTipoOcupante.class" \
    "gcom/micromedicao/hidrometro/HidrometroLocalArmazenagem.class" \
    "gcom/operacional/FonteCaptacao.class" \
    "gcom/seguranca/transacao/AlteracaoTipo.class" \
    "gcom/atendimentopublico/ligacaoesgoto/LigacaoEsgotoCaixaInspecao.class" \
    "gcom/atendimentopublico/LigacaoOrigem.class" \
    "gcom/atendimentopublico/ligacaoesgoto/LigacaoEsgotoDestinoAguasPluviais.class" \
    "gcom/operacional/ZonaAbastecimento.class" \
    "gcom/cadastro/imovel/PiscinaVolumeFaixa.class" \
    "gcom/cadastro/localidade/QuadraPerfil.class" \
    "gcom/atendimentopublico/ordemservico/EquipamentosEspeciais.class" \
    "gcom/cadastro/geografico/RegiaoDesenvolvimento.class" \
    "gcom/cadastro/endereco/LogradouroTipo.class" \
    "gcom/cadastro/imovel/ImovelTipoPropriedade.class" \
    "gcom/operacional/SistemaAbastecimento.class" \
    "gcom/operacional/SistemaEsgotoTratamentoTipo.class" \
    "gcom/cadastro/imovel/ImovelTipoConstrucao.class"

echo "[Fase 3] Limpeza preventiva de classes duplicadas no WAR concluída."
echo "----------------------------------------------------------"

# [3/7] Iniciando container
echo "[3/7] Iniciando container 'jboss-servidor'..."
JAVA_OPTS_BASE="-server -Xms128m -Xmx1024m -XX:MaxPermSize=512m \
  -Dorg.jboss.resolver.warning=true \
  -Dsun.rmi.dgc.client.gcInterval=3600000 \
  -Dsun.rmi.dgc.server.gcInterval=3600000"

DEBUG_MODE="on"
DEBUG_PORT=8787

if [ "$DEBUG_MODE" = "on" ]; then
  JAVA_OPTS="${JAVA_OPTS_BASE} -agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=${DEBUG_PORT}"
else
  JAVA_OPTS="${JAVA_OPTS_BASE}"
fi

docker run -d \
  --name jboss-servidor \
  -e JAVA_HOME=/opt/jdk1.6.0_45 \
  -e JAVA_OPTS="$JAVA_OPTS" \
  -v /usr/lib/jvm/jdk1.6.0_45:/opt/jdk1.6.0_45:ro \
  -v "$LIB_DIR":/opt/jboss-5.1.0.GA/server/default/lib \
  -v "$CONF_DIR/jboss-log4j.xml":/opt/jboss-5.1.0.GA/server/default/conf/jboss-log4j.xml:ro \
  -v "$CONF_DIR/jboss-service.xml":/opt/jboss-5.1.0.GA/server/default/conf/jboss-service.xml:ro \
  -v "$CONF_DIR/standardjboss.xml":/opt/jboss-5.1.0.GA/server/default/conf/standardjboss.xml:ro \
  -v "$DEPLOY_DIR":/opt/jboss-5.1.0.GA/server/default/deploy \
  -v "$LOG_DIR":/opt/jboss-5.1.0.GA/server/default/log \
  -v "$REPORTS_DIR":/opt/gsan/reports \
  --ulimit nofile=65536:65536 \
  --restart unless-stopped \
  --network minha-rede-legada \
  -p 8080:8080 \
  -p 1099:1099 \
  -p ${DEBUG_PORT}:${DEBUG_PORT} \
  meu-jboss5-local

if [ $? -ne 0 ]; then
  echo "   ❌ Falha ao iniciar o container JBoss."
  exit 1
fi
echo "   ✅ Container iniciado com sucesso."

echo "[4/7] Aguardando 10 segundos para estabilização..."
sleep 10

echo "[5/7] Verificando filas JMS e DataSources..."
docker logs jboss-servidor 2>&1 | grep -E "QueueService|DataSource" | tail -n 20
echo "   ✅ Log inicial JMS/DataSource exibido (verifique se há 'started')."

echo "[6/7] JBoss acessível em: http://localhost:8080 ou http://<IP_DO_HOST>:8080"
echo "=========================================================="

echo "[7/7] Monitorando logs em tempo real..."
echo "Pressione Ctrl+C para sair — o servidor continuará ativo."
echo "=========================================================="
docker logs -f jboss-servidor
