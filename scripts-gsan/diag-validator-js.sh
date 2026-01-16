#!/bin/bash
set -euo pipefail

WAR="/root/docker/jboss5/deploy/gcom.ear/gcom.war"
SRC="/opt/gsan/gcom"

# JSP relativo (pode passar outro como parâmetro)
JSP_REL="${1:-jsp/cadastro/projeto/projeto_inserir.jsp}"

JSP_DEPLOY="$WAR/$JSP_REL"
JSP_SRC="$SRC/$JSP_REL"

echo "============================================================"
echo "DIAG VALIDATOR-JS"
echo "JSP_REL: $JSP_REL"
echo "============================================================"

echo
echo "=== 1) Arquivos ==="
ls -l "$JSP_DEPLOY" 2>/dev/null || echo "❌ Não existe no DEPLOY: $JSP_DEPLOY"
ls -l "$JSP_SRC"    2>/dev/null || echo "❌ Não existe no FONTE:  $JSP_SRC"

echo
echo "=== 2) Trecho do <head> até <body> (DEPLOY) ==="
if [[ -f "$JSP_DEPLOY" ]]; then
  awk 'NR<=180 {print NR ":" $0} /<body/{exit}' "$JSP_DEPLOY" | sed -n '1,220p'
fi

echo
echo "=== 3) Linhas-chave: <html:javascript> e <html:form> (DEPLOY) ==="
if [[ -f "$JSP_DEPLOY" ]]; then
  echo "-- <html:javascript> --"
  grep -nE "<html:javascript" "$JSP_DEPLOY" || echo "❌ Não achei <html:javascript> no DEPLOY"
  echo
  echo "-- <html:form> --"
  grep -nE "<html:form" "$JSP_DEPLOY" || echo "❌ Não achei <html:form> no DEPLOY"
fi

echo
echo "=== 4) Extrair nomes (DEPLOY) ==="
if [[ -f "$JSP_DEPLOY" ]]; then
  FORMNAME_JS=$(grep -oE 'formName="[^"]+"' "$JSP_DEPLOY" | head -n 1 | cut -d'"' -f2 || true)
  FORMNAME_FORM=$(grep -oE '<html:form[^>]*name="[^"]+"' "$JSP_DEPLOY" | head -n 1 | sed -E 's/.*name="([^"]+)".*/\1/' || true)
  echo "formName (html:javascript): ${FORMNAME_JS:-<vazio>}"
  echo "name     (html:form)     : ${FORMNAME_FORM:-<vazio>}"
  echo
  echo "Atributos do <html:javascript> (DEPLOY):"
  grep -nE "<html:javascript" "$JSP_DEPLOY" | head -n 1 || true
  echo
  echo "Checagem rápida:"
  grep -nE "dynamicJavascript|staticJavascript" "$JSP_DEPLOY" | head -n 5 || echo "(não há dynamic/static explicitados)"
fi

echo
echo "=== 5) validator.xml / validator-compesa.xml: existe form com o nome do JSP? (DEPLOY) ==="
if [[ -f "$JSP_DEPLOY" ]]; then
  V1="$WAR/WEB-INF/validator.xml"
  V2="$WAR/WEB-INF/validator-compesa.xml"
  echo "Arquivos:"
  ls -l "$V1" "$V2" 2>/dev/null || true
  echo
  for VN in "${FORMNAME_JS:-}" "${FORMNAME_FORM:-}"; do
    [[ -z "${VN:-}" ]] && continue
    echo "--- Procurando <form name=\"$VN\"> ---"
    grep -nE "<form[[:space:]]+name=\"$VN\"" "$V1" "$V2" 2>/dev/null | head -n 20 || echo "❌ Não achei $VN no validator*.xml"
  done
fi

echo
echo "=== 6) struts-config(s): existe form-bean com esse nome? (DEPLOY) ==="
if [[ -f "$JSP_DEPLOY" ]]; then
  echo "Buscando em: $WAR/WEB-INF/*.xml e subpastas..."
  for BN in "${FORMNAME_JS:-}" "${FORMNAME_FORM:-}"; do
    [[ -z "${BN:-}" ]] && continue
    echo "--- Procurando <form-bean name=\"$BN\" ---"
    grep -RInE "<form-bean[[:space:]]+name=\"$BN\"" "$WAR/WEB-INF" 2>/dev/null | head -n 30 || echo "❌ Não achei form-bean $BN nos struts-configs"
  done
fi

echo
echo "=== 7) Mostrar 80 linhas do JSP (DEPLOY) ao redor do <html:javascript> ==="
if [[ -f "$JSP_DEPLOY" ]]; then
  LINE=$(grep -nE "<html:javascript" "$JSP_DEPLOY" | head -n 1 | cut -d: -f1 || true)
  if [[ -n "${LINE:-}" ]]; then
    START=$((LINE-25)); [[ $START -lt 1 ]] && START=1
    END=$((LINE+55))
    awk -v s="$START" -v e="$END" 'NR>=s && NR<=e {print NR ":" $0}' "$JSP_DEPLOY"
  fi
fi

echo
echo "=== 8) Mesmas checagens no FONTE (se existir) ==="
if [[ -f "$JSP_SRC" ]]; then
  echo "-- <html:javascript> (FONTE) --"
  grep -nE "<html:javascript" "$JSP_SRC" || echo "❌ Não achei <html:javascript> no FONTE"
  echo
  echo "-- <html:form> (FONTE) --"
  grep -nE "<html:form" "$JSP_SRC" || echo "❌ Não achei <html:form> no FONTE"
fi

echo
echo "============================================================"
echo "FIM"
echo "============================================================"
