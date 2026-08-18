# OpenSEO — stack Coolify

Serviciul `OpenSEO` din Coolify. `docker-compose.yml` din acest folder este sursa;
copiază-l în Coolify și reîncarcă fișierul compose.

[OpenSEO](https://openseo.so/) ([every-app/open-seo](https://github.com/every-app/open-seo))
este alternativa open source la Ahrefs/Semrush: keyword research, backlinks,
rank tracking, audituri de site, plus un endpoint MCP pentru agenți AI.
Imaginea este `ghcr.io/every-app/open-seo:latest`.

## Arhitectură: de ce două containere

Build-ul Docker oficial rulează cu autentificarea aplicației **oprită**
(`AUTH_MODE=local_noauth` — un singur utilizator `admin@localhost`, fără nicio
verificare). Documentația upstream cere explicit ca deploy-ul Docker să stea
doar în spatele unui proxy cu autentificare proprie.

- `proxy` — un Caddy mic, singurul serviciu cu domeniu public
  (`SERVICE_FQDN_PROXY_8080`). Face basic auth și trimite mai departe către
  aplicație. Hash-ul bcrypt se calculează la pornire din parola generată de
  Coolify, deci nu există niciun secret în fișier.
- `open-seo` — aplicația, doar pe rețeaua internă a stack-ului, fără domeniu.

Alternative respinse:

- `AUTH_MODE=hosted` (login real prin Better Auth) lasă înregistrarea deschisă
  oricui — nu există variabilă care să o închidă — iar subdomeniul devine
  public prin certificate transparency logs. Fiecare utilizator străin ar
  consuma credite DataForSEO plătite de noi.
- Middleware basicauth pe Traefik cere editarea manuală a etichetelor de
  router generate de Coolify (nume de forma `https-0-<uuid>`), pas fragil și
  nedeclarativ; Caddy-ul din compose face același lucru fără pași în UI.
  În plus, Coolify a avut cazuri în care etichetele au fost șterse la
  redeploy și servicii protejate au rămas publice în tăcere
  ([coolify#6939](https://github.com/coollabsio/coolify/issues/6939)).
- Basic auth-ul nativ din UI-ul Coolify (*Configuration → General*) există
  doar pentru aplicații din git, nu pentru resurse compose — cererea pentru
  servicii este încă deschisă
  ([coolify#9032](https://github.com/coollabsio/coolify/discussions/9032)).
- Forward-auth cu SSO (Tinyauth, Authelia, oauth2-proxy) ar da un singur
  login pentru toate serviciile din Coolify, dar este infrastructură la
  nivel de server, nu de stack; de luat în calcul dacă apar mai multe
  servicii fără autentificare proprie.

## Configurare

Variabile în tab-ul *Environment Variables* al serviciului:

- **`DATAFORSEO_API_KEY` — obligatorie.** Fără ea aplicația pornește, dar
  afișează un modal de "API key not configured" și funcțiile de bază
  (keywords, rank tracking, backlinks, audituri) nu întorc nimic; doar
  integrarea Google Search Console merge fără. Formatul este
  `base64("login:parola")` din contul
  [app.dataforseo.com](https://app.dataforseo.com/api-access). Consumul se
  plătește direct la DataForSEO, pay-as-you-go: top-up minim $50, audit
  ~$0.01/20 pagini, keyword research ~$0.035/150 rezultate. Atenție:
  API-ul de backlinks cere un angajament de $100/lună după trial — restul
  API-urilor nu.
- `OPENROUTER_API_KEY`, `OPENROUTER_MODEL` — opționale; pornesc funcțiile AI
  (SAM). Fără ele restul aplicației merge normal.
- `SERVICE_USER_OPENSEO` / `SERVICE_PASSWORD_OPENSEO` — utilizatorul și parola
  de basic auth, generate de Coolify; de aici se citesc valorile de login.

Telemetria upstream este oprită din compose (`OPENSEO_TELEMETRY_DISABLED=1`,
`DO_NOT_TRACK=1`).

## Self-host vs. planul hosted

Planul hosted ([openseo.so/pricing](https://openseo.so/pricing)) costă $10/lună
cu $10 de credit inclus (se resetează lunar). Prețurile per unitate sunt mai
mari decât DataForSEO direct, dar planul include backlinks la $0.08/verificare,
fără angajamentul de $100/lună pe care îl cere DataForSEO la self-host.

Regula de decizie: dacă backlinks contează, hosted este net mai ieftin
($120/an vs. $1.200/an doar angajamentul); fără backlinks, self-host-ul cu un
top-up de $50 la prețuri brute iese mai ieftin, iar creditul nu expiră.

## Porturi și acces

- **8080 — proxy-ul Caddy.** Coolify leagă domeniul de el prin
  `SERVICE_FQDN_PROXY_8080`; accesul trece prin Traefik, apoi prin basic auth.
- **3001 — aplicația.** Doar `expose`, fără domeniu și fără port pe gazdă.
  `ALLOWED_HOST` se completează singur cu domeniul proxy-ului — Vite refuză
  alte hostname-uri.

## MCP

Endpoint-ul MCP este `https://<domeniu>/mcp`. În `local_noauth` aplicația nu
cere nimic, deci basic auth-ul proxy-ului este singura barieră: clientul MCP
trebuie să trimită header-ul `Authorization: Basic base64(user:parola)` cu
valorile `SERVICE_USER_OPENSEO` / `SERVICE_PASSWORD_OPENSEO`.

## Note

- Toată starea (baza de date D1/SQLite locală, KV, tokenuri) stă în volumul
  `open-seo-data`, montat la `/app/.wrangler`. Nimic nu se pierde la redeploy.
- Healthcheck-ul aplicației folosește `node -e fetch(...)` pe `/api/health`,
  pentru că imaginea nu garantează `curl`/`wget`/`bash`; al proxy-ului este un
  test TCP cu `nc`, pentru că un probe HTTP ar primi 401 de la basic auth.
- Pinuiește versiunea schimbând tag-ul imaginii (`:v1.2.3` în loc de
  `:latest`) când upstream-ul devine instabil.
