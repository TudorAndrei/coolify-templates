# Calibre — stack Coolify

Serviciul `Calibre` din Coolify (context `internetland`, UUID `gg0c4cggwgkcccs8c8cs000s`).
`docker-compose.yml` din acest folder este sursa; copiază-l în Coolify și reîncarcă fișierul compose.

- Bibliotecă: <https://calibre.tudorandrei.xyz>
- Descărcări (Shelfmark): <https://calibre-download.tudorandrei.xyz>
- Bibliotecă Calibre pe gazdă: `/home/tudor/calibre_config/books`

## Ce s-a corectat, 11 august 2026

**Descărcare → conversie.** Containerul `downloader` rulează deja Shelfmark v1.3.5
(numele vechi de imagine `calibre-web-automated-book-downloader` trimite acolo).
Shelfmark 1.x scrie în `INGEST_DIR`, implicit `/books`. Variabila nu era setată, deci
descărcările rămâneau într-un folder fără volum, în interiorul containerului, și nu
ajungeau niciodată la CWA. Acum `INGEST_DIR=/cwa-book-ingest`.

**Autentificare comună.** Shelfmark citește `app.db` de la CWA prin `AUTH_METHOD=cwa` și
`CWA_DB_PATH=/auth/app.db`. Volumul `cwa-config` este montat a doua oară la `/auth:ro`;
Shelfmark deschide baza cu `mode=ro` și nu scrie nimic în ea. Conturile CWA sunt sincronizate
în `users.db` a lui Shelfmark, cu rolurile păstrate.

**Hardcover.** `HARDCOVER_TOKEN` pentru CWA, `HARDCOVER_ENABLED` plus `HARDCOVER_API_KEY`
pentru Shelfmark. Ambele citesc aceeași variabilă Coolify, `HARDCOVER_TOKEN`.
Token-ul se ia de la <https://hardcover.app/account/api>.

**Serviciul `bypass` a fost scos.** `CLOUDFLARE_PROXY_URL` nu mai există în Shelfmark 1.x,
deci containerul nu era folosit. Shelfmark are bypasser intern: `USE_CF_BYPASS=true`.
Alternativa externă cere API de tip FlareSolverr (`EXT_BYPASSER_URL`), pe care imaginea
`cloudflarebypassforscraping` nu îl expune.

**Volume în locul folderelor de gazdă.** Folderul de ingest era `/tmp/data/calibre-web/ingest`,
pe care Ubuntu îl golește periodic. Acum este volumul `cwa-book-ingest`. Config-ul lui
Shelfmark, `shelfmark-config`, este de asemenea volum — înainte nu era păstrat deloc, deci
utilizatorii și setările se pierdeau la fiecare redeploy.

**Healthcheck la ambele servicii.** Shelfmark interoga `/request/api/status`, care cere
autentificare. Cu `AUTH_METHOD=cwa` ar fi răspuns 401 și containerul ar fi rămas permanent
`unhealthy`. Calea corectă, scutită de autentificare, este `/api/health`.
CWA răspunde pe portul intern 8083 și pornește lent, deci `start_period: 120s`.

**Portul 8084 nu mai este publicat.** Era legat direct pe gazdă, deci ocolea Traefik.
Acum doar `expose`, iar accesul trece prin domeniu.

## Note

- Ambele imagini își repară singure drepturile pe volume la pornire: Shelfmark prin
  `make_writable` în `entrypoint.sh`, CWA prin serviciul s6 `cwa-init`. Nu este nevoie de
  `chown` manual pe volumele noi.
- `PGID=100` la ambele containere, ca CWA să poată șterge fișierele după ingest.
- CWA este configurat cu `config_calibre_dir = /calibre-library/books`. Fișierul
  `metadata.db` de 0 octeți din `/home/tudor/calibre_config` este o rămășiță, nu este folosit.
- Conversia automată este deja pornită în CWA: `auto_convert = 1`, format țintă `epub`.
