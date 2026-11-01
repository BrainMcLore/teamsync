# Self-hosting the API

The server is a Python API with persistent storage. Use `server/.env.example` for supported environment variables and the checked-in Docker/Render configuration as deployment recipes.

```sh
python3 -m pip install -r server/requirements.txt
uvicorn server.app:app --host 0.0.0.0 --port 8000
```

For container deployment use `compose.yaml` in the complete source package. Configure durable database/media storage, a public HTTPS URL and provider callback URLs before inviting users.

Keep database connection strings, session signing secrets and Discord Client Secret in the host's private environment settings. Do not put secrets in the application, APK, repository or release archives. Steam/Discord login requires the relevant provider configuration and matching callbacks; inspect the environment template and API configuration for exact names.

The bundled `render.yaml` is a hosting recipe, not a guarantee of free service or unchanged provider terms. Check provider limits, persistence and cold-start behavior before relying on a hosted team workspace. SQLite is useful locally; a shared deployment should use its configured persistent database backend.

See [architecture](architecture.md), [integrations](integrations.md) and [development](development.md).
