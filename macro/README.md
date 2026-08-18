# Macro — stack Coolify

Bootstrap pentru [macro-inc/macro](https://github.com/macro-inc/macro): spațiu de
lucru unificat (e-mail, chat, documente, sarcini, agenți, CRM), Rust plus
SolidJS, licență AGPL-3.0.

- `Dockerfile` — imaginea „stiva Macro într-un singur container".
- `entrypoint.sh` — pornirea: dockerd interior, depozit, `just stack up`.
- `docker-compose.yml` — sursa pentru Coolify; copiaz-o în serviciu și
  reîncarcă fișierul compose.

## Citește asta înainte de a porni

**Macro nu are un mod de self-hosting.** Depozitul nu publică imagini și nu
conține un compose de producție. Ce rulează aici este **stiva de dezvoltare
locală** — aceeași pe care o pornește `just stack up`, aceeași pe care
previzualizările oficiale de pe Fly o rulează într-o singură mașină virtuală
(vezi `infra/preview/README.md` din depozit).

Consecințele sunt reale, nu formale:

- **Docker-in-Docker.** Stiva pornește ea însăși ~25 de containere prin docker
  compose. Containerul Coolify are nevoie de `privileged: true` și rulează un
  daemon Docker propriu. Aceasta este arhitectura folosită de Macro pentru
  previzualizări, nu o improvizație.
- **Fără AWS, fără e-mail real.** S3, SQS și DynamoDB sunt LocalStack. E-mailul
  este capturat de Mailpit, nu trimis. Autentificarea este fără parolă, prin cod
  pe e-mail; codul se citește la `<domeniu>/mailpit/`.
- **Binare de depanare.** Serviciile Rust se compilează în profil `debug` și
  rulează cu identități FusionAuth fixe, definite în cod.
- **Resurse.** Previzualizarea Fly primește 8 vCPU și 16 GB RAM, cu observația
  din depozit că este supradimensionată deliberat. Sub 8 GB RAM nu are rost
  încercarea. Volumele cer 40–60 GB.
- **Prima pornire durează.** Clonare, lanț de compilare Nix, tot spațiul de
  lucru Rust, pachetul frontend, migrări, indexuri de căutare. Peste o oră este
  normal. Pornirile următoare refolosesc volumele.

## Securitate

**Nu expune stiva public fără autentificare la margine.** Mailpit este servit la
`/mailpit/` pe aceeași origine, iar autentificarea se face prin coduri trimise pe
e-mail — deci oricine deschide URL-ul poate citi codul și intra ca orice
utilizator. Depozitul notează același lucru despre previzualizările proprii și
listează oauth2-proxy ca pas viitor de întărire.

Până atunci: pune parolă de bază (Coolify o oferă la nivel de serviciu) sau
ține domeniul privat.

Containerul este privilegiat. Nu îl pune pe aceeași gazdă cu servicii pe care
nu vrei să le expui unei evadări din container.

## Configurare în Coolify

Variabile de mediu:

| Variabilă | Implicit | Rol |
| --- | --- | --- |
| `MACRO_REPO_URL` | depozitul public | Sursa clonării |
| `MACRO_REPO_REF` | `main` | Ramura sau eticheta |
| `MACRO_AUTO_UPDATE` | `true` | `false` îngheață depozitul la commit-ul clonat |
| `MACRO_ENV_OVERLAY` | gol | Dotenv pe mai multe linii, pentru chei de integrare |

`MACRO_ENV_OVERLAY` se suprapune peste mediul local definit în cod. Pornirea nu
cere nicio cheie: infrastructura locală (LocalStack, Mailpit, FusionAuth) este
deterministă și scrisă în cod. Cheile sunt necesare doar pentru funcțiile care
ies în afară — modelele AI, Gmail, Stripe.

Domeniul se leagă la portul 8090, singura origine a stivei: frontend la
`/app/`, API-urile, WebSocket-urile și Mailpit trec toate prin proxy-ul Caddy
al stivei.

## Ce nu este verificat

Fișierele din acest folder nu au fost pornite încă. Sunt derivate din modul în
care depozitul își rulează propriile previzualizări, nu dintr-o rulare reușită
pe Coolify. Puncte de urmărit la prima încercare:

1. **`nix develop` în container.** Instalarea este single-user, cu
   `filter-syscalls = false` și `sandbox = false`. Dacă Nix refuză să
   construiască, alternativa este instalarea manuală a lanțului de compilare
   (Rust, cargo-zigbuild, Zig, Bun, sqlx-cli, just), fără flake.
2. **Redirectarea după autentificare.** `authentication_service` trimite
   browserul spre `http://localhost:{FRONTEND_PORT}`. Pe un domeniu public
   asta poate rupe fluxul de conectare; previzualizările Fly funcționează la
   `/app/`, deci comportamentul trebuie confirmat.
3. **Verificarea de sănătate** interoghează `/app/`. Dacă pachetul frontend
   ajunge în altă cale, corectează testul.

Diagnostic din container: `docker exec -it <container> bash`, apoi
`cd /srv/macro/repo && nix develop --command just stack status`.
