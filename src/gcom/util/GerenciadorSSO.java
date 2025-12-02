package gcom.util;

import java.io.IOException;
import java.util.Collection;
import javax.servlet.http.Cookie;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpSession;
import gcom.fachada.Fachada;
import gcom.seguranca.FiltroSegurancaParametro;
import gcom.seguranca.SegurancaParametro;
import gcom.seguranca.acesso.usuario.FiltroUsuario;
import gcom.seguranca.acesso.usuario.Usuario;
import gcom.util.filtro.ParametroNaoNulo;
import gcom.util.filtro.ParametroSimples;

public class GerenciadorSSO {
	private Cookie[] cookies;
	private String conteudoDoCookie;
	private HttpServletRequest httpRequest;
	private HttpClient http = new HttpClient();
	private String token;
	private SegurancaParametro parametro;

	public GerenciadorSSO(HttpServletRequest httpRequest) throws IOException {
		this.httpRequest = httpRequest;
		this.cookies = httpRequest.getCookies();
		this.validarToken();
		this.setSessions();
	}

	public boolean isOk() throws IOException {
		return http.getStatusCode() == 200;
	}
	
	public boolean isLogado() throws IOException {
		return isOk();
	}

	public String getConteudoDoCookie() {
		return this.conteudoDoCookie;
	}

	public String getToken() {
		return this.token;
	}

	private void setSessions() throws IOException {
	    // Só tenta logar via SSO se o portal respondeu 200
	    if (!this.isOk() || usuarioAutenticado()) {
	        return;
	    }

	    HttpSession session = httpRequest.getSession(false);
	    if (session == null) {
	        session = httpRequest.getSession(true);
	    }

	    FiltroUsuario filtroUsuario = new FiltroUsuario();
	    filtroUsuario.adicionarParametro(
	            new ParametroSimples(FiltroUsuario.ID, this.getConteudoDoCookie())
	    );
	    filtroUsuario.adicionarParametro(new ParametroNaoNulo(FiltroUsuario.ID));

	    Collection<?> usuarios = Fachada.getInstancia()
	            .pesquisar(filtroUsuario, Usuario.class.getName());

	    // >>> HARDENING: se não encontrar usuário, não lança exceção, só não loga via SSO
	    if (usuarios == null || usuarios.isEmpty()) {
	        return;
	    }

	    Usuario usuario = (Usuario) usuarios.iterator().next();

	    session.setAttribute("usuarioLogado", usuario);
	    Fachada.getInstancia().montarMenuUsuario(session, httpRequest.getRemoteAddr());
	}

//	private void setSessions() throws IOException {
//		if (this.isOk() && !usuarioAutenticado()) {
//			
//			HttpSession session = httpRequest.getSession(false);
//			
//			FiltroUsuario filtroUsuario = new FiltroUsuario();
//			filtroUsuario.adicionarParametro(new ParametroSimples(FiltroUsuario.ID, this.getConteudoDoCookie()));
//			filtroUsuario.adicionarParametro(new ParametroNaoNulo(FiltroUsuario.ID));
//			
//			Usuario usuario = (Usuario) Fachada.getInstancia().pesquisar(filtroUsuario, Usuario.class.getName()).iterator().next();
//			
//			session.setAttribute("usuarioLogado", usuario);
//			
//			Fachada.getInstancia().montarMenuUsuario(session, httpRequest.getRemoteAddr());
//		}
//	}

	public boolean usuarioAutenticado() {
		HttpSession session = httpRequest.getSession();
		
		if (session != null) {
			Usuario usuario = (Usuario) session.getAttribute("usuarioLogado");
			if (usuario != null) {
				return true;
			}
		}

		return false;
	}
	

	public String getUrlPortal(){
	    // Se o parâmetro não foi encontrado ou não tem valor, evita NPE
	    if (parametro == null || parametro.getValor() == null) {
	        // aqui podemos:
	        // - retornar "" (sem URL de portal)
	        // - ou um valor padrão, se você quiser
	        return "";
	    }
	    return parametro.getValor();
	}

//	private void validarToken() throws IOException {
//		if (existeAlgumCookie())
//			this.token = getCookie().getValue();
//		
//		FiltroSegurancaParametro filtro = new FiltroSegurancaParametro();
//		filtro.adicionarParametro(new ParametroSimples(FiltroSegurancaParametro.NOME, SegurancaParametro.NOME_PARAMETRO_SEGURANCA.URL_SEGURANCA.name()));
//		filtro.adicionarParametro(new ParametroNaoNulo(FiltroSegurancaParametro.NOME));
//		
//		parametro = (SegurancaParametro) Fachada.getInstancia().pesquisar(filtro, SegurancaParametro.class.getName()).iterator().next();
//		
//		this.conteudoDoCookie = http.GetPageContent(parametro.getValor() + "/authorization?token=" + token);
//	}


	private void validarToken() throws IOException {
	    // Se não existe cookie "gsan", não tem token para validar: sai sem fazer nada.
	    if (!existeAlgumCookie()) {
	        return;
	    }

	    this.token = getCookie().getValue();

	    FiltroSegurancaParametro filtro = new FiltroSegurancaParametro();
	    filtro.adicionarParametro(new ParametroSimples(
	            FiltroSegurancaParametro.NOME,
	            SegurancaParametro.NOME_PARAMETRO_SEGURANCA.URL_SEGURANCA.name()
	    ));
	    filtro.adicionarParametro(new ParametroNaoNulo(FiltroSegurancaParametro.NOME));

	    Collection<?> resultados = Fachada.getInstancia()
	            .pesquisar(filtro, SegurancaParametro.class.getName());

	    // >>> HARDENING: se não houver parâmetro, não valida SSO e não derruba o sistema
	    if (resultados == null || resultados.isEmpty()) {
	        // Ambiente sem configuração de SSO: segue sem validar token
	        return;
	    }

	    this.parametro = (SegurancaParametro) resultados.iterator().next();

	    this.conteudoDoCookie = http.GetPageContent(
	            parametro.getValor() + "/authorization?token=" + token
	    );
	}

	private boolean existeAlgumCookie() {
		return this.cookies != null && getCookie() != null;
	}

	private Cookie getCookie() {
		Cookie cookieGsan = null;

		for (Cookie cookie : cookies) {
			if (cookie != null) {
				if (cookie.getName().equals("gsan")) {
					cookieGsan = cookie;
				}
			}
		}

		return cookieGsan;
	}
}
