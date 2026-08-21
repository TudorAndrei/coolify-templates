# Repository Instructions

Docker Compose templates for services self-hosted on [Coolify](https://coolify.io), one folder per
service. `README.md` is the catalogue and the setup notes; this file is how to change a template
without breaking the service it describes.

## Every template is a mirror

A `docker-compose.yml` here mirrors a service that is already running in Coolify. Coolify holds the
live copy, this repository holds the readable one — the same YAML plus the comments explaining why
each setting is what it is. Changing a template is half the job: paste it back into the Coolify
resource and redeploy, or the mirror drifts and starts describing a service that no longer exists.

Coolify's generator writes these files back, so match what it emits: single-quoted values, its key
order, named volumes at the bottom, and no top-level `name:` — Coolify sets the project name from
the resource. Four `dclint` rules are off for this reason, each with its reason in `.dclintrc`.

## Magic variables

Coolify generates these at deploy time and injects them into the container, which is how credentials
stay out of a public repository. Declaring one and reading it back are different spellings, and
mixing them up is the most common way to get a healthy container on no domain:

| Spelling | Effect |
| --- | --- |
| `- SERVICE_FQDN_APP_8080` | Bare, no `=`. Routes the generated domain to port 8080. |
| `- SERVICE_URL_APP_3000` | The same routing, and the value carries the `http://` scheme. |
| `- SERVICE_FQDN_APP=/api` | Appends a path to the generated address. |
| `${SERVICE_FQDN_APP}` | Reads the bare domain back. **No port suffix when reading.** |
| `${SERVICE_URL_APP}` | Reads the address with its scheme. |
| `${SERVICE_USER_X}` / `${SERVICE_PASSWORD_X}` | Generated username and password. |
| `${SERVICE_PASSWORD_64_X}` | 64 characters, no symbols. Use for JWT and CSRF keys. |
| `${SERVICE_REALBASE64_64_X}` / `${SERVICE_HEX_64_X}` | 64-character Base64 or hex secret. |
| `${VAR-default}` | An ordinary variable with a fallback, for what an operator may want to change. |

The identifier joins multiple words with a hyphen, because Coolify reads a trailing `_<digits>` as
the port: `SERVICE_URL_MY-APP_3000` names the app `MY-APP`, while `SERVICE_URL_MY_APP_3000` does
not. Two services sharing an identifier share the generated value — that is how the ExcaliDash
frontend and backend agree on one origin.

## Conventions

- **Every credential is a `${VARIABLE}` reference**, given its value in the Coolify *Environment
  Variables* tab. `gitleaks` and `detect-private-key` read every file on every commit; `hk.pkl`
  records why their globs are widened past the builtin defaults.
- **`expose:`, not `ports:`.** Traefik reaches the container over the internal network. `ports:` is
  for raw TCP that Traefik cannot route, such as Forgejo's SSH on 22222.
- **A healthcheck on every service**, with `depends_on: condition: service_healthy` wherever start
  order matters. Probe `127.0.0.1` rather than `localhost`, which resolves to `::1` first against a
  process listening on `0.0.0.0` only.
- **`$$` in a healthcheck command** passes a literal `$` to the container's shell, so
  `$${POSTGRES_USER}` is expanded inside the container and `${...}` is expanded by Compose.
- **`restart: unless-stopped`** on every service.
- **Comments in English, service READMEs in Romanian**, root `README.md` in English. That mix is why
  `typos` is absent from the pipeline — its dictionary is English only.

## Adding a service

1. Create `<service>/` holding `docker-compose.yml` and `README.md`.
2. Write the README in Romanian: what the service is, which Coolify variables to set, and the traps.
3. Add a row to the table in the root `README.md`.
4. Run `hk check --all`.
