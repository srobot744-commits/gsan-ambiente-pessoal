<logic:notPresent scope="session" name="origemGIS">
<body alink="black" vlink="black">
    <table width="1024" border="0" cellspacing="5" cellpadding="0">
        <tr>
            <td height="0" valign="top" class="topstrip">
                <table width="100%" height="0" border="0" cellpadding="0" cellspacing="0">
                    <tr>
                        <td height="0" valign="bottom">

			<%
			    // Tentativa de usar logoMarca do sistema
			    Object logoObj = getServletContext().getAttribute("logoMarca");
			    String logo = (logoObj != null ? logoObj.toString().trim() : "");

			    // Se o GSAN não tiver logo configurado,
			    // usamos SEMPRE a imagem física do sistema
			    String logoUrl;
			    if (logo == null || logo.equals("")) {
			        logoUrl = request.getContextPath() + "/imagens/logo_saneacre_pequeno.jpeg";
			    } else {
			        logoUrl = logo;
			    }
			%>

			<img src="<%= logoUrl %>" width="71"  border="0" alt="Logo" />

                        </td>

                        <td width="35%" align="center">
                            <br>
                            <marquee bgcolor="#CBE5FE"
                                     title="titulo"
                                     valign="top"
                                     loop="true"
                                     scrollamount="4"
                                     behavior="scroll"
                                     direction="left">
                                <font color="black">
				    <strong>BEM VINDOS AO GSAN, SISTEMA COMERCIAL DA SANEACRE</strong>
				  <% // <strong>${requestScope.mensagemAviso}</strong>%>
                                </font>
                            </marquee>
                        </td>

                        <td align="right" valign="bottom">
                            <img src="<bean:message key='caminho.imagens'/>logo_menu_superior.gif" border="0">
                        </td>
                    </tr>

                    <table cellpadding="0" cellspacing="0" border="0" class="layerCaminhoMenu">
                        <tr>
                            <logic:present name="caminhoMenuFuncionalidade">
                                <td>
                                    <font size="1">${sessionScope.caminhoMenuFuncionalidade}</font>
                                </td>
                            </logic:present>
                        </tr>
                    </table>

                </table>
            </td>
        </tr>
    </table>
</body>
</logic:notPresent>
