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

## Git hooks

[hk](https://hk.jdx.dev) runs the checks on every commit. `mise install` installs
the hooks, so a fresh clone needs nothing else.

The two that matter here are `gitleaks` and `detect-private-key`. Every file in
this repository is public, and a Coolify template is exactly the kind of file
where a real token gets pasted "just to test it" and then committed.

Both are overridden with `glob = "**/*"` and an empty `types` list. The builtins
default to `types = ["text"]`, and hk does not classify a `.pem` as text — the
step then gets zero files, hk skips it, and the commit goes through. A lone
`secret.pem` holding an RSA private key committed cleanly until that was fixed.

The rest: `dclint` and `hadolint` for the compose files and the Dockerfile,
`shellcheck` and `shfmt` for `macro/entrypoint.sh`, `rumdl` for the Markdown,
and a conventional-commit check on the message.

`typos` is deliberately absent — the READMEs and the shell comments are in
Romanian and its dictionary is English.

Run everything by hand with `hk check --all`, or fix what is fixable with
`hk fix --all`.

Four `dclint` rules are disabled in `.dclintrc`, each with the reason in the
file. They fight Coolify's own output conventions rather than describing real
defects.

## License

MIT
