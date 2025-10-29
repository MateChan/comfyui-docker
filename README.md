# ComfyUI Docker

## Run

```bash
docker compose up -d --build
```

- UI at <http://localhost:8188>

## Folders

- Read-only: `custom_nodes/`, `models/`
- Writable: `input/`, `output/`, `user/`

## Reset

- Remove containers: `docker compose down`
- Full wipe (data loss): `docker compose down --volumes`
