# Hermes Agent — stack Coolify

Serviciul `Hermes` din Coolify. `docker-compose.yml` din acest folder este sursa;
copiază-l în Coolify și reîncarcă fișierul compose.

Imaginea este `nousresearch/hermes-agent:latest` ([Nous Research](https://hermes-agent.nousresearch.com/docs/user-guide/docker)).
Un singur container: PID 1 este `/init` (s6-overlay), care supraveghează gateway-ul
și dashboard-ul și le repornește la cădere.

## Configurare la prima pornire

Containerul pornește și fără configurare — gateway-ul cade și este repornit de s6,
dar containerul rămâne sus. Configurarea se face din terminalul Coolify al
containerului:

```bash
hermes setup      # asistentul de configurare; scrie în /opt/data
hermes doctor     # verifică instalarea
hermes gateway status
```

Echivalent de pe gazdă: `docker exec -it hermes hermes setup`.

Tot ce scrie asistentul (config, `.env` cu chei API, sesiuni, memorii, skills,
loguri) stă în volumul `hermes-data`, montat la `/opt/data`. Nimic nu se pierde
la redeploy. Nu monta același volum la două gateway-uri — starea nu se împarte.

## Porturi și acces

- **9119 — dashboard-ul web.** Coolify leagă domeniul de el prin
  `SERVICE_FQDN_HERMES_9119`. Pentru că iese public prin Traefik, autentificarea
  basic-auth este pornită; utilizatorul și parola sunt variabilele magice
  `SERVICE_USER_HERMES` / `SERVICE_PASSWORD_HERMES`, generate de Coolify —
  valorile sunt în tab-ul *Environment Variables* al serviciului.
- **8642 — API-ul OpenAI-compatibil.** Oprit implicit. Pentru pornire,
  decomentează cele trei linii `API_SERVER_*` din compose; `API_SERVER_KEY`
  este obligatorie când serverul ascultă pe `0.0.0.0`. Dacă vrei API-ul pe un
  domeniu, adaugă și o variabilă `SERVICE_FQDN_API_8642`.

Niciun port nu este publicat direct pe gazdă — doar `expose`, iar accesul trece
prin Traefik.

## CLI-ul `hermes` din interiorul agentului

Terminalul agentului rulează ca utilizatorul `hermes`, cu un mediu filtrat în
care `/opt/hermes/bin` nu este pe PATH — de aceea agentul raportează că CLI-ul
„nu este instalat". Binarul există, în arborele imuabil `/opt/hermes`:

- `/opt/hermes/bin/hermes` — shim-ul (cel folosit și de `docker exec`);
- `/opt/hermes/.venv/bin/hermes` — binarul propriu-zis din venv, dacă shim-ul
  refuză să ruleze ca utilizator neprivilegiat.

Cere-i agentului să folosească calea completă, de exemplu
`/opt/hermes/bin/hermes profile create <nume>`. Comenzile care scriu (profiluri,
config) scriu sub `/opt/data`, deci trec de `HERMES_WRITE_SAFE_ROOT=/opt/data`.
Alternativa sigură rămâne terminalul Coolify:
`docker exec -it hermes hermes profile create <nume>`.

## Note

- Healthcheck-ul este un test TCP pe 9119 prin `/dev/tcp` din bash, ca să nu
  depindă de `curl`/`wget` în imagine. Dashboard-ul răspunde și înainte de
  `hermes setup`, deci deploy-ul nu pică pe un container neconfigurat.
- Resurse recomandate de upstream: 2–4 GB RAM, 2 nuclee, 2+ GB disc cu sesiuni
  active. Limitele se pun din UI-ul Coolify, nu din compose.
- Imaginea remapează utilizatorul intern `hermes` prin `HERMES_UID`/`HERMES_GID`
  (implicit 10000). Cu volum numit nu este nevoie de nimic manual; variabilele
  contează doar la bind mount-uri de pe gazdă.
