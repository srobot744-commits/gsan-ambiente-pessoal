<%@ taglib uri="/WEB-INF/struts-logic.tld" prefix="logic"%>

<logic:notPresent scope="session" name="origemGIS">

<table width="1024" cellspacing="4" cellpadding="0">
	<tr>
    	<td>
      	<table width="100%" cellpadding="2" class="footer">
        	<tr>
          		<td  align="left">
	          		<logic:present scope="application" name="versaoDataBase">
					Banco: ${applicationScope.versaoDataBase}
					</logic:present>
					<logic:notPresent scope="application" name="versaoDataBase">
					PMSS
					</logic:notPresent>
				</td>
          		<td align="right">Vers&atilde;o: 1.1.0 (Online) 30/11/2025 - 11:48:38 </td>
        	</tr>
      	</table>
		</td>
  	</tr>
</table>
</logic:notPresent>
