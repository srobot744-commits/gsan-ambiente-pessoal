package gcom.gui.util;

import gcom.cadastro.sistemaparametro.SistemaParametro;
import gcom.fachada.Fachada;

import java.io.IOException;

import javax.servlet.Filter;
import javax.servlet.FilterChain;
import javax.servlet.FilterConfig;
import javax.servlet.ServletException;
import javax.servlet.ServletRequest;
import javax.servlet.ServletResponse;
import javax.servlet.http.HttpServlet;


/**
 * Filtro respons·vel por verificar se a sess„o do usu·rio expirou o tempo 
 *
 * @author Pedro Alexandre
 * @date 05/07/2006
 */
public class FiltroAtualizarQuadroAvisos extends HttpServlet implements Filter {

	private static final long serialVersionUID = 1L;
	@SuppressWarnings("unused")
	private FilterConfig filterConfig;
	
	/**
	 * <Breve descriÁ„o sobre o caso de uso>
	 * 
	 * @author Pedro Alexandre
	 * @date 05/07/2006
	 *
	 * @param filterConfig
	 */
	public void init(FilterConfig filterConfig) {
		this.filterConfig = filterConfig;
	}

	
	/**
	 * <Breve descriÁ„o sobre o caso de uso>
	 *
	 * @author Pedro Alexandre
	 * @date 05/07/2006
	 *
	 * @param request
	 * @param response
	 * @param filterChain
	 * @throws ServletException
	 * @throws IOException
	 */

    public void doFilter(ServletRequest request, ServletResponse response, FilterChain filterChain) throws ServletException, IOException {
        try {

                // Busca a mensagem de avisos 
                SistemaParametro sistemaParametro = Fachada.getInstancia()
                                .pesquisarParametrosDoSistema();

                // Prote√ß√£o contra retorno nulo ou mensagem nula
                if (sistemaParametro != null && sistemaParametro.getMensagemSistema() != null) {
                        request.setAttribute("mensagemAviso",
                                        sistemaParametro.getMensagemSistema());
                } else {
                        // opcional: garante que o atributo exista, mesmo vazio
                        request.setAttribute("mensagemAviso", "");
                }

                filterChain.doFilter(request, response);

        } catch (ServletException sx) {
                throw sx;
        } catch (IOException iox) {
                throw iox;
        }
    }


/*
	public void doFilter(ServletRequest request, ServletResponse response, FilterChain filterChain) throws ServletException, IOException {
		try {

			//Busca a mensagem de avisos 
			SistemaParametro sistemaParametro = Fachada.getInstancia()
					.pesquisarParametrosDoSistema();
			request.setAttribute("mensagemAviso",
					sistemaParametro.getMensagemSistema());

			
				filterChain.doFilter(request, response);


		} catch (ServletException sx) {
			throw sx;
		} catch (IOException iox) {
			throw iox;
		}
	}
*/
	
	/**
	 * <Breve descriÁ„o sobre o caso de uso>
	 *
	 * @author Pedro Alexandre
	 * @date 05/07/2006
	 *
	 */
	public void destroy() {
	}
}
