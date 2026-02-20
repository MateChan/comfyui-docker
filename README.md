# ComfyUI Docker

## Run

```bash
docker compose up -d --build
```

or

```bash
PUID=$(id -u) PGID=$(id -g) docker compose up -d --build
```

- UI at <http://localhost:8188>

## Folders

- `custom_nodes/`, `models/`, `input/`, `output/`, `user/`

## Reset

- Remove containers: `docker compose down`
- Full wipe (data loss): `docker compose down --volumes`
