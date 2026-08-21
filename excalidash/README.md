# ExcaliDash — stack Coolify

Excalidraw multi-utilizator, self-hosted: cont pentru fiecare om, desene persistente, editare în
timp real, istoric de versiuni și partajare cu domeniu de vizibilitate. `docker-compose.yml` din
acest folder este sursa; copiază-l într-o resursă **Docker Compose** din Coolify.

Trei containere: `frontend` (nginx, servește UI-ul și face proxy pentru `/api/` și `/socket.io/`),
`backend` (REST + Socket.IO + Prisma) și `postgresql`.

## Variabile de mediu

Coolify generează singur valorile `SERVICE_*`; restul se completează în tab-ul
*Environment Variables* al serviciului.

| Variabilă | Cine o dă | Rol |
| --- | --- | --- |
| `SERVICE_URL_EXCALIDASH_80` | Coolify | Domeniul public, rutat spre portul 80 al `frontend` |
| `SERVICE_USER_POSTGRESQL` | Coolify | Utilizatorul bazei |
| `SERVICE_PASSWORD_POSTGRESQL` | Coolify | Parola bazei |
| `SERVICE_PASSWORD_64_JWT` | Coolify | Semnătura sesiunilor |
| `SERVICE_PASSWORD_64_CSRF` | Coolify | Semnătura tokenurilor CSRF |
| `POSTGRESQL_DATABASE` | tu (opțional) | Numele bazei; implicit `excalidash` |
| `AUTH_MODE` | tu (opțional) | `local`, `hybrid` sau `oidc_enforced`; implicit `local` |

`SERVICE_PASSWORD_*` este generat fără simboluri, deci intră fără escape în DSN-ul PostgreSQL.
`SERVICE_PASSWORDWITHSYMBOLS_*` **nu** are această proprietate — nu îl folosi pentru `DATABASE_URL`.

## Primul admin

Nu există utilizator implicit. La prima pornire backendul scrie în log un cod de înregistrare de
unică folosință, iar interfața îl cere înainte să creeze contul de administrator:

```bash
docker compose logs backend --tail=200 | grep "BOOTSTRAP SETUP"
```

Codul se consumă la prima utilizare. Dacă introduci unul greșit sau expirat, în log apare altul.

## Ce se sparge primul

- **`FRONTEND_URL` diferit de adresa reală.** Vine din `SERVICE_URL_EXCALIDASH`, deci este corect
  atâta timp cât domeniul se schimbă din Coolify. Dacă pui un domeniu propriu direct în Traefik,
  fără să treacă prin Coolify, autentificarea și socketul de colaborare cad amândouă pe verificarea
  de origine — simptomul este „login merge, dar desenul nu se sincronizează".
- **Buclă de redirect HTTP → HTTPS.** Backendul redirecționează singur când `FRONTEND_URL` începe
  cu `https://`. Traefik-ul din Coolify trimite `X-Forwarded-Proto`, iar nginx-ul din `frontend` îl
  propagă, deci lanțul este corect. Dacă totuși apare o buclă, adaugă `ENFORCE_HTTPS_REDIRECT=false`
  în loc să umbli la Traefik.
- **`TRUST_PROXY` prea mic.** Cu `1`, backendul crede că fiecare cerere vine de la nginx-ul din
  fața lui: limitele de rată se aplică pe o singură adresă, adică pe toți utilizatorii deodată.
  Valoarea `2` numără ambele hopuri, Traefik și nginx.
- **O singură replică de backend.** Prezența în colaborare se ține în memoria procesului, deci a
  doua replică ar rupe sesiunile de editare în două. Upstream documentează explicit limitarea; nu
  scala serviciul până nu apare un adaptor Socket.IO partajat.
- **Volumul `excalidash-backend-data`.** Cu PostgreSQL nu mai ține baza, dar ține starea Prisma și
  directorul de backup. `docker compose down -v` îl șterge; nu adăuga `-v` din reflex.

## PostgreSQL în loc de SQLite

Upstream livrează implicit SQLite. Acest fișier folosește PostgreSQL, pentru că backupul și
restaurarea trec prin aceleași unelte ca restul stivei.

Alegerea se face **o singură dată, la primul deploy**. Nu există migrare de date între cei doi
furnizori: schimbarea lui `DATABASE_PROVIDER` pe o instalare vie duce la o bază goală, nu la datele
mutate.

## Actualizare

Imaginile sunt fixate pe `0.5.1`. Proiectul se declară el însuși **beta**, iar notele de lansare
conțin pași manuali de la o versiune la alta, deci `latest` ar aduce migrări neanunțate la un
redeploy întâmplător.

Actualizarea înseamnă: citește notele de lansare, fă backup la baza de date și la volum, apoi
schimbă tagul în acest fișier și reîncarcă fișierul compose în Coolify.

## MCP — cât de greu este portul

Scopul stivei este ca agenții să deseneze pe aceleași pânze ca oamenii. **Partea de MCP nu este
încă aici.** `yctimlin/mcp_excalidraw` vine cu propriul server de pânză, care ține elementele în
memorie și nu știe nimic despre desenele din ExcaliDash; pus lângă stiva asta ar fi o a doua pânză,
separată. Iar serverul lui MCP vorbește pe stdio, nu pe rețea, deci rulează pe mașina agentului, nu
într-un Coolify.

Portul este fezabil, pentru că ambele proiecte au exact granițele potrivite.

### Ce se poate refolosi nemodificat

Aproximativ 90% din codul util al lui `mcp_excalidraw` — fabrica de elemente, normalizarea,
geometria, aliniere/distribuire/grupare, `describe`, exportul `.excalidraw` și `.excalidraw.md` —
sunt funcții pure peste un tablou de elemente Excalidraw. Nu ating rețeaua.

Tot accesul la pânză trece printr-un singur fișier, `src/core/canvas-client.ts` (13 KB, ~25 funcții
exportate), importat de doar patru module. Acela este fișierul de rescris.

Licențele nu se ciocnesc: `mcp_excalidraw` este MIT, ExcaliDash este LGPL-3.0, iar adaptorul
vorbește peste rețea, deci nu se leagă de codul LGPL.

### Ce a construit deja ExcaliDash

- **Chei de API** (`exd_…`, antet `Bearer`), cu domenii `drawings:read|write` și
  `collections:read|write`, plus ocolirea CSRF pentru cererile care nu vin din browser. Agentul are
  deci identitate proprie, fără sesiune de browser și fără parolă în configurația MCP.
- **Concurență optimistă** pe `PUT /drawings/:id`: trimiți `version`, iar serverul răspunde `409
  VERSION_CONFLICT` cu versiunea curentă dacă altcineva a scris între timp.
- **Istoric automat**: fiecare scriere de scenă creează un `DrawingSnapshot` înainte de update, deci
  agentul primește „undo" fără să construiască nimic.

### Cele trei etape ale portului

| Etapă | Ce dă | Efort |
| --- | --- | --- |
| 1. Client REST | Agentul listează, deschide, citește și scrie desene reale | 2–3 zile |
| 2. Împingere live | Oamenii văd editările agentului fără reîncărcare | 1–2 zile |
| 3. Captură de ecran | Bucla vizuală: desenează → vede → corectează | 3–5 zile |

**Etapa 1** înseamnă rescrierea lui `canvas-client.ts` peste `/drawings`. Diferența de model este
singura muncă reală: `mcp_excalidraw` adresează *elemente* (`PUT /api/elements/:id`), ExcaliDash
adresează *documente* (`PUT /drawings/:id` cu tot tabloul). Adaptorul ține scena în memorie pe
desen, transformă CRUD-ul pe element în citește–modifică–scrie, trimite `version` și reîncarcă la
`409`.

**Etapa 2** este un client Socket.IO care emite `element-update`. Două lucruri de știut înainte:

- Stratul de socket este **doar releu** — nu persistă nimic. Persistența rămâne pe `PUT`. Cele două
  căi trebuie făcute amândouă, altfel editarea fie dispare la reîncărcare, fie nu apare live.
- `io.use` acceptă **numai JWT**, din cookie sau din `handshake.auth.token`. Cheia de API nu merge
  pe socket. Fie agentul face login cu parolă ca să obțină un JWT, fie se adaugă în `io.use` vreo
  15 linii care acceptă și `exd_…` — un PR mic și curat pentru upstream.

**Etapa 3** este partea grea și cea mai puțin previzibilă. La `mcp_excalidraw`, `export/image` și
`create_from_mermaid` nu se fac pe server: cererea merge prin WebSocket la un **tab de browser
deschis**, care randează. Nimic din asta nu se transferă. Ori randezi în Node cu `exportToSvg` din
`@excalidraw/excalidraw` peste jsdom, ori pornești un Playwright care se autentifică în ExcaliDash
și deschide desenul. Fonturile și golurile din jsdom sunt sursa surprizelor.

### Concluzie

Trei zile pentru un agent care chiar scrie în desenele echipei; una-două săptămâni pentru tot,
inclusiv bucla vizuală. Partea care ar fi fost cu adevărat costisitoare — conturi, permisiuni,
istoric, identitate pentru agent — este deja construită în ExcaliDash.

## Surse

- [ExcaliDash](https://github.com/ZimengXiong/ExcaliDash) și
  [ghidul de deployment](https://github.com/ZimengXiong/ExcaliDash/blob/main/docs/DEPLOYMENT.md)
- [mcp_excalidraw](https://github.com/yctimlin/mcp_excalidraw)
