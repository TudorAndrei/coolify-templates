# Forgejo + runner — stack Coolify

Serviciul `Forgejo` din Coolify: forge-ul Git, PostgreSQL și un runner de
Actions. `docker-compose.yml` din acest folder este sursa; copiază-l în Coolify
și reîncarcă fișierul compose.

Domeniu: `forgejo.tudorandrei.xyz`. SSH pe portul `22222` al gazdei (singurul
port publicat direct; restul trece prin Traefik).

## Ce a fost reparat față de varianta inițială

### 1. `$` simplu în `command` — cauza principală a eșecului la înregistrare

Compose interpolează `$FORGEJO_INSTANCE_URL` **în YAML, înainte de pornirea
containerului**, folosind mediul gazdei. Acolo variabila nu există, deci
comanda ajunge în container ca `--instance ""` și înregistrarea cade cu o
eroare care nu spune nimic despre cauză.

Soluția este `$$`, care lasă un `$` literal să treacă mai departe către shell-ul
din container. Același tipar era deja folosit corect în healthcheck-ul
PostgreSQL (`$${POSTGRES_USER}`).

### 2. Tokenul de înregistrare era scris în clar

Tokenul este o credențială și fișierul intră în git. Acum vine din
`${FORGEJO_RUNNER_REGISTRATION_TOKEN}`, care se completează în tab-ul
*Environment Variables* al serviciului din Coolify.

**Tokenul vechi (`PZCHlHlm…`) este compromis și trebuie rotit.** Din
*Site Administration → Actions → Runners* se șterge runner-ul și se generează
un token nou.

### 3. Etichete care nu pot rula acțiuni

`node:22-bookworm` nu are `sudo` și nici uneltele de build pe care le presupun
majoritatea acțiunilor din marketplace, deci job-urile cad cu erori greu de
citit. Imaginile `catthehacker` sunt cele pe care `act` și `forgejo-runner` le
așteaptă pentru `ubuntu-latest`.

Etichetele se scriu în `/data/.runner` **la înregistrare**. Dacă modifici
`FORGEJO_RUNNER_LABELS` mai târziu, nu se schimbă nimic până nu ștergi
`/data/.runner` și nu reînregistrezi runner-ul.

### 4. `FORGEJO__actions__ENABLED=true` explicit

Fără el, un runner se poate conecta cu succes și apoi să nu primească niciodată
un job — fără mesaj de eroare pe niciuna dintre părți.

## Verificarea instalării

```bash
docker compose logs -f forgejo-runner        # așteaptă „runner registered"
docker compose exec forgejo-runner cat /data/.runner
```

În interfață, runner-ul apare în *Site Administration → Actions → Runners* cu
starea `idle`.

## Ce mai poate cădea

- **Cache.** Serverul de cache ascultă în containerul runner-ului, iar
  job-urile pornesc pe rețele Docker separate, create prin socket-ul gazdei.
  Dacă `actions/cache` blochează sau expiră, adaugă un `config.yml` cu
  `cache.actions_cache_url_override`, sau oprește cache-ul cu
  `cache.enabled: false` până îl reglezi.
- **Clonarea în job.** Job-urile clonează pe `ROOT_URL`, adică domeniul public.
  Merge doar dacă gazda își rezolvă propriul domeniu (hairpin NAT prin Traefik).
- **Socket-ul Docker.** Montarea lui dă runner-ului control complet asupra
  gazdei. Este acceptabil pentru un forge cu un singur utilizator; nu este
  acceptabil dacă cineva din afară poate declanșa workflow-uri.

## Versiune

Imaginea este fixată pe `forgejo:8`, lansată în 2024 și cu mai multe versiuni
majore în urmă. Actualizările se fac **o versiune majoră pe rând**, cu backup al
volumului `forgejo-data` și al bazei înainte de fiecare pas.
