#!/bin/bash
# ==========================================================
# SCRIPT: Fase 2 - Compilação do GSAN (Ant + JDK 1.6)
# VERSÃO: 57 (ajustada - Validator XML no WAR + melhorias)
# ==========================================================
# Funções:
# - Remove EAR e cache antigos
# - Normaliza XMLs com dos2unix
# - Corrige ejb-jar.xml (EJBFix)
# - Compila o GSAN via Ant (JDK 1.6)
# - Copia relatórios e DataSources
# - Reutiliza o jbossmq-destinations-service.xml da Fase 1
# - GARANTE validator.xml / validator-compesa.xml dentro do WAR (Struts Validator JS)
# ==========================================================

JAVA6_HOME="/usr/lib/jvm/jdk1.6.0_45"
ANT_BIN="/opt/apache-ant-1.9.16/bin/ant"
CONF_DIR="/root/docker/jboss5/conf"
DEPLOY_DIR="/root/docker/jboss5/deploy"
CONFIG_DIR="/opt/gsan/config"
CACHE_DIR="/root/docker/jboss5/tmp"

echo "=========================================================="
echo "     INICIANDO FASE 2/3: COMPILAÇÃO DO GSAN (V57)"
echo "=========================================================="

# [1/9] Limpeza inteligente de EAR e cache
echo "[1/9] Limpando deploy e cache antigos..."
if [ -d "$DEPLOY_DIR/gcom.ear" ]; then
  echo "   ➤ Removendo EAR antigo..."
  rm -rf "$DEPLOY_DIR/gcom.ear"
  echo "   ✅ EAR antigo removido."
else
  echo "   ℹ️  Nenhum EAR antigo encontrado (ok)."
fi

if [ -d "$CACHE_DIR" ]; then
  echo "   ➤ Limpando cache temporário do JBoss..."
  rm -rf "$CACHE_DIR"/*
  echo "   ✅ Cache do JBoss limpo."
else
  echo "   ⚠️  Diretório de cache não encontrado, ignorando."
fi

# ==========================================================
# [CHECKPOINT] Ajuste automático do Hibernate.properties
# ==========================================================
HBP_FILE="/opt/gsan/src/gcom/properties/hibernate.properties"

echo "----------------------------------------------------------"
echo "🔍 Verificando configuração do DataSource do Hibernate..."
if [ -f "$HBP_FILE" ] && grep -q "java:/PostgresDS" "$HBP_FILE"; then
    echo "🔧 Corrigindo DataSource: substituindo 'java:/PostgresDS' → 'java:/jdbc/GSAN_COMERCIAL'"
    sed -i 's#java:/PostgresDS#java:/jdbc/GSAN_COMERCIAL#g' "$HBP_FILE"
    echo "✅ Ajuste aplicado com sucesso no Hibernate.properties"
else
    echo "✅ Hibernate.properties já configurado corretamente (ou arquivo não encontrado)."
fi
echo "----------------------------------------------------------"

# [2/9] Limpeza de BOMs
echo "[2/9] Aplicando dos2unix..."
find /opt/gsan/descriptors -type f -name "*.xml" -exec dos2unix {} \; 2>/dev/null

# [2.5/9] Correção automática dos ejb-jar.xml (EJBFix)
echo "[2.5/9] Verificando e corrigindo ejb-jar.xml (EJBFix)..."

EJBDIRS=(
  "/opt/gsan/src/gcom/batch"
  "/opt/gsan/src/gcom/faturamento"
  "/opt/gsan/src/gcom/arrecadacao"
  "/opt/gsan/src/gcom/micromedicao"
  "/opt/gsan/src/gcom/cobranca"
  "/opt/gsan/src/gcom/gerencial"
)

for DIR in "${EJBDIRS[@]}"; do
  if [ -d "$DIR" ]; then
    find "$DIR" -type f -name "ejb-jar.xml" | while read -r XML; do
      if ! grep -q "<message-driven-destination>" "$XML"; then
        echo "   ➕ Corrigindo: $XML"
        sed -i '/<transaction-type>Bean<\/transaction-type>/a\
  <message-driven-destination>\n    <destination-type>javax.jms.Queue<\/destination-type>\n  <\/message-driven-destination>' "$XML"
      fi
    done
  fi
done
echo "   ✅ Correções EJBFix aplicadas (se necessárias)."

# [3/9] Compilação
echo "[3/9] Compilando projeto com Ant (JDK 1.6)..."
cd /opt/gsan || exit 1
env JAVA_HOME="$JAVA6_HOME" "$ANT_BIN"
if [ $? -ne 0 ]; then
  echo "❌ Erro na compilação do GSAN."
  exit 1
fi
echo "   ✅ Compilação concluída com sucesso."

# [4/9] Copiar relatórios
echo "[4/9] Copiando relatórios..."
cp /opt/gsan/reports/*.jasper /root/docker/gsan-reports/ 2>/dev/null
echo "   ✅ Relatórios copiados."

# [5/9] Garantir diretório config
echo "[5/9] Verificando diretório /opt/gsan/config..."
mkdir -p "$CONFIG_DIR"

# [6/9] Verificar arquivos JMS e DataSources
echo "[6/9] Verificando arquivos JMS e DataSources..."

# --- JMS ---
if [ ! -f "$CONFIG_DIR/jbossmq-destinations-service.xml" ]; then
  echo "   ⚙️  Copiando JMS gerado pela Fase 1..."
  if [ -f "$CONF_DIR/jbossmq-destinations-service.xml" ]; then
    cp "$CONF_DIR/jbossmq-destinations-service.xml" "$CONFIG_DIR/"
    echo "   ✅ JMS copiado de $CONF_DIR."
  else
    echo "   ⚠️  JMS da Fase 1 não encontrado, criando fallback mínimo..."
    tee "$CONFIG_DIR/jbossmq-destinations-service.xml" > /dev/null <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<mbean code="org.jboss.mq.server.jmx.Queue"
       name="jboss.mq.destination:name=BatchGerarResumoFaturamentoMDB,service=Queue">
  <depends optional-attribute-name="DestinationManager">jboss.mq:service=DestinationManager</depends>
</mbean>
EOF
  fi
else
  echo "   ✅ JMS já existente em $CONFIG_DIR."
fi

# --- DataSources ---
for DS in comercial gerencial; do
  FILE="$CONFIG_DIR/gsan_${DS}-ds.xml"
  if [ ! -f "$FILE" ]; then
    echo "   ⚙️  Criando $FILE..."
    tee "$FILE" > /dev/null <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<datasources>
  <local-tx-datasource>
    <jndi-name>jdbc/GSAN_${DS^^}</jndi-name>
    <connection-url>jdbc:postgresql://postgres94:5432/gsan_${DS}</connection-url>
    <driver-class>org.postgresql.Driver</driver-class>
    <user-name>postgres</user-name>
    <password>nnk232867</password>
    <min-pool-size>5</min-pool-size>
    <max-pool-size>20</max-pool-size>
    <idle-timeout-minutes>5</idle-timeout-minutes>
    <exception-sorter-class-name>org.jboss.resource.adapter.jdbc.vendor.PostgreSQLExceptionSorter</exception-sorter-class-name>
  </local-tx-datasource>
</datasources>
EOF
  fi
done

# [7/9] Copiar arquivos de configuração para o deploy
echo "[7/9] Copiando configurações para volume Docker..."
cp "$CONFIG_DIR"/*.xml "$DEPLOY_DIR/" 2>/dev/null
echo "   ✅ Configurações copiadas."

# [8/9] Validar EAR expandido
echo "[8/9] Validando EAR expandido..."
EAR_DIR="$DEPLOY_DIR/gcom.ear"
WAR_WEBINF="$EAR_DIR/gcom.war/WEB-INF"

if [ -d "$EAR_DIR" ]; then
  echo "   ✅ EAR expandido em $EAR_DIR"
else
  echo "   ⚠️  EAR não localizado. Verifique o build.xml e o target do Ant."
  exit 1
fi

# ==========================================================
# [8.5/9] GARANTIR STRUTS VALIDATOR XMLs NO WAR (CRÍTICO)
# - Sem isso, NÃO existe validate<FormName>() no browser.
# ==========================================================
echo "----------------------------------------------------------"
echo "[8.5/9] Garantindo Struts Validator XMLs no WAR (validator.xml / validator-compesa.xml)..."

mkdir -p "$WAR_WEBINF"

copy_if_missing() {
  local fname="$1"
  local fixed_src="/opt/gsan/gcom/WEB-INF/$fname"

  if [ -f "$WAR_WEBINF/$fname" ]; then
    echo "   ✅ $fname já existe no WAR."
    return 0
  fi

  if [ -f "$fixed_src" ]; then
    echo "   ➤ Copiando $fname de $fixed_src para $WAR_WEBINF/"
    cp -f "$fixed_src" "$WAR_WEBINF/"
    return 0
  fi

  # fallback: tenta localizar em qualquer lugar do projeto
  local found
  found=$(find /opt/gsan -type f -name "$fname" 2>/dev/null | head -n 1)

  if [ -n "$found" ]; then
    echo "   ➤ Encontrado $fname em: $found"
    echo "   ➤ Copiando para $WAR_WEBINF/"
    cp -f "$found" "$WAR_WEBINF/"
    return 0
  fi

  echo "   ❌ NÃO encontrei $fname no /opt/gsan."
  echo "      Isso impede a geração do JS validate<FormName>() no Struts."
  return 1
}

ERR=0
copy_if_missing "validator.xml" || ERR=1
copy_if_missing "validator-compesa.xml" || ERR=1

if [ "$ERR" -ne 0 ]; then
  echo "   ❌ Falha ao garantir os XMLs do Validator. Corrija a origem desses arquivos no projeto."
  exit 1
fi

echo "   ✅ Validator XMLs garantidos dentro do WAR."
echo "----------------------------------------------------------"

# ==========================================================
# [9/9] Garantindo driver PostgreSQL no classpath do JBoss
# ==========================================================
echo "[9/9] Garantindo driver PostgreSQL no classpath do JBoss..."
PG_DRIVER_SRC="/opt/gsan/lib/driver-postgres"
PG_DRIVER_DST="/root/docker/jboss5/jboss-files/lib"

if [ -d "$PG_DRIVER_SRC" ]; then
    PG_JAR=$(find "$PG_DRIVER_SRC" -maxdepth 1 -type f -name "postgresql-*.jar" | head -n 1)
    if [ -n "$PG_JAR" ]; then
        echo "   → Encontrado driver: $(basename "$PG_JAR")"
        echo "   → Copiando para $PG_DRIVER_DST ..."
        cp -f "$PG_JAR" "$PG_DRIVER_DST"/
        if [ $? -eq 0 ]; then
            echo "   ✅ Driver PostgreSQL copiado com sucesso."
        else
            echo "   ❌ Falha ao copiar o driver PostgreSQL. Verifique permissões."
        fi
    else
        echo "   ⚠️ Nenhum arquivo 'postgresql-*.jar' encontrado em $PG_DRIVER_SRC"
    fi
else
    echo "   ⚠️ Diretório $PG_DRIVER_SRC não encontrado."
fi

echo "=========================================================="
echo "   ✅ FASE 2 CONCLUÍDA COM SUCESSO (GSAN COMPILADO)"
echo "=========================================================="
