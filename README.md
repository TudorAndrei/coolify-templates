# coolify-templates

Docker Compose templates for services I self-host on [Coolify](https://coolify.io).

Each folder holds a `docker-compose.yml` that is the source of truth for one
Coolify service, plus a `README.md` with the setup notes — the environment
variables that matter, the traps, and what breaks first.

| Service | What it is |
| --- | --- |
| [`calibre/`](calibre/) | Calibre-Web Automated + book downloader |
| [`forgejo/`](forgejo/) | Forgejo forge, PostgreSQL, and an Actions runner |
| [`hermes/`](hermes/) | Nous Research Hermes agent |
| [`macro/`](macro/) | Macro, with a custom image |

## Usage

Copy a `docker-compose.yml` into a new Coolify **Docker Compose** resource, then
set the environment variables listed in that folder's `README.md`.

The files rely on Coolify's magic variables — `SERVICE_FQDN_*`, `SERVICE_URL_*`,
`SERVICE_USER_*`, `SERVICE_PASSWORD_*`. Coolify generates their values and
injects them at deploy time, so they stay out of this repository. Outside
Coolify these compose files need those variables supplied by hand.

## Secrets

No credential belongs in this repository. Anything secret is referenced as
`${VARIABLE}` and set in the Coolify *Environment Variables* tab of the service.

The READMEs are written in Romanian; the comments in the compose files are in
English.

## License

MIT
