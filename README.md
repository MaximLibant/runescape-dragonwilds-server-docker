## RuneScape: DragonWilds Dedicated Server Docker

A Docker container for running a RuneScape: DragonWilds dedicated server using DepotDownloader.

## Fork Notice

This is a modified fork of [indifferentbroccoli/runescape-dragonwilds-server-docker](https://github.com/indifferentbroccoli/runescape-dragonwilds-server-docker). It was modified in July 2026 to preserve dedicated server configuration, pass world-selection settings more explicitly, and publish images to GitHub Container Registry.

This fork remains licensed under GPL-3.0. See [LICENSE](LICENSE) for the full license text.

## Server Requirements

| Resource | Minimum       | Recommended |
|----------|---------------|-------------|
| CPU      | 4 cores       | 4+ cores    |
| RAM      | 8GB           | 16GB        |
| Storage  | 10GB          | 20GB        |

> [!NOTE]
> RAM required is 2GB + 1GB per player. For a full 6-player server you need 8GB.

## How to use

Copy the `.env.example` file to a new file called `.env`. Then use either `docker compose` or `docker run`.

This fork publishes images to GitHub Container Registry:

```text
ghcr.io/maximlibant/runescape-dragonwilds-server-docker:latest
```

### Docker Compose

```yaml
services:
  runescape-dragonwilds:
    image: ghcr.io/maximlibant/runescape-dragonwilds-server-docker:latest
    restart: unless-stopped
    container_name: runescape-dragonwilds
    stop_grace_period: 30s
    ports:
      - 7777:7777/udp
    env_file:
      - .env
    volumes:
      - ./server-files:/home/steam/server-files
```

Then run:

```bash
docker-compose up -d
```

### Docker Run

```bash
docker run -d \
    --restart unless-stopped \
    --name runescape-dragonwilds \
    --stop-timeout 30 \
    -p 7777:7777/udp \
    --env-file .env \
    -v ./server-files:/home/steam/server-files \
    ghcr.io/maximlibant/runescape-dragonwilds-server-docker:latest
```

## Environment Variables

| Variable           | Default            | Info                                                                                      |
|--------------------|--------------------|-------------------------------------------------------------------------------------------|
| PUID               | 1000               | User ID for file permissions                                                              |
| PGID               | 1000               | Group ID for file permissions                                                             |
| UPDATE_ON_START    | true               | If set to false, skips downloading and validating server files on startup                 |
| OWNER_ID           |                    | **Required.** Your RuneScape: DragonWilds Player ID (found in Settings Menu in-game)     |
| SERVER_NAME        | DragonWildsServer  | Display name of the server                                                                |
| DEFAULT_WORLD_NAME | MyWorld            | Name of the default world created on first startup                                        |
| ADMIN_PASSWORD     |                    | **Required.** Password to access Server Management in-game                               |
| WORLD_PASSWORD     |                    | Optional join password. Leave empty for a public server                                   |
| DEFAULT_PORT       | 7777               | The UDP port the server listens on                                                        |
| MAX_PLAYERS        | 6                  | Maximum number of players allowed on the server                                           |

> [!NOTE]
> If your server doesn't appear, check that UDP port 7777 is forwarded through your firewall/router and that `OWNER_ID` and `ADMIN_PASSWORD` are set.

## Configuration Behavior

On startup, this image updates the env-managed values in `DedicatedServer.ini` while preserving game-managed fields such as `ServerGuid`, `KnownPlayerList`, and other unmanaged settings.

`DEFAULT_WORLD_NAME` is also passed as a launch override so recovery paths continue to target the configured world. If you rename or switch worlds, keep stale `.sav` files out of the active `SaveGames` directory so the game cannot select an old slot.

## Port Forwarding

Forward **7777 UDP only**. Every router between you and your ISP will need port forwarding configured. See [portforward.com](https://portforward.com) for router-specific guides.

> [!IMPORTANT]
> The internal and external ports **must match**. If you change `DEFAULT_PORT`, update the port mapping in your compose file to match — e.g. `9000:9000/udp` with `DEFAULT_PORT=9000`. Mismatched ports will cause players to be kicked back to the title screen on join.

## User Management

Dedicated Servers divide users into three categories:

- **Owner** — the player whose Player ID matches `OWNER_ID` in config
- **Admin** — anyone who entered the `ADMIN_PASSWORD` in the Server Management screen
- **Regular users**

Owners can ban and unban anyone (online or offline). Admins can ban regular users who are online.

## Volumes

- `/home/steam/server-files` — Server installation files, saves, and configuration
