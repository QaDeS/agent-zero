# Building and Running Agent Zero with Model Overrides Locally

This guide explains how to build the Agent Zero Docker image locally with the model override feature and use it with different users.

## Quick Start

### 1. Build the Local Image

```bash
# Option A: Simple build (recommended for local use)
docker build -f Dockerfile.localdev -t agent-zero:model-overrides .

# Option B: Full build (takes longer, builds from base)
docker build -f DockerfileLocal -t agent-zero:model-overrides --build-arg BRANCH=local .
```

### 2. Run with Docker Compose

```bash
# Run the container
docker-compose -f docker-compose.local.yml up -d

# View logs
docker-compose -f docker-compose.local.yml logs -f

# Stop the container
docker-compose -f docker-compose.local.yml down
```

Access the UI at: http://localhost:50080

## Running as a Different User

### Method 1: Using `sudo` with Docker Compose

```bash
# Create a directory for the other user's data
sudo mkdir -p /home/otheruser/agent-zero-data
sudo chown -R otheruser:otheruser /home/otheruser/agent-zero-data

# Run docker-compose as the other user
sudo -u otheruser docker-compose -f docker-compose.local.yml up -d

# Or switch to the user first
su - otheruser
docker-compose -f /path/to/docker-compose.local.yml up -d
```

### Method 2: Using Docker User Namespace

Edit `docker-compose.local.yml` and uncomment the user line:

```yaml
services:
  agent-zero:
    image: agent-zero:model-overrides
    user: "1000:1000"  # UID:GID of the target user
    volumes:
      - /home/otheruser/agent-zero-data:/a0
```

### Method 3: Using Podman (Rootless)

Podman runs containers rootless by default:

```bash
# As any user, run:
podman build -f Dockerfile.localdev -t agent-zero:model-overrides .
podman-compose -f docker-compose.local.yml up -d
```

### Method 4: Docker Rootless Mode

```bash
# Install docker rootless (as the user)
dockerd-rootless-setuptool.sh install

# Run docker-compose normally (it will use rootless docker)
docker-compose -f docker-compose.local.yml up -d
```

## Making the Image Available System-Wide

### Option A: Save and Load the Image

```bash
# As the builder user, save the image
docker save agent-zero:model-overrides | gzip > agent-zero-model-overrides.tar.gz

# Copy to other users or systems
scp agent-zero-model-overrides.tar.gz otheruser@host:/tmp/

# On the target system, load the image (as any user with docker access)
gunzip -c agent-zero-model-overrides.tar.gz | docker load
```

### Option B: Use a Local Registry

```bash
# Run a local registry (if not already running)
docker run -d -p 5000:5000 --name registry registry:2

# Tag and push to local registry
docker tag agent-zero:model-overrides localhost:5000/agent-zero:model-overrides
docker push localhost:5000/agent-zero:model-overrides

# Other users can now pull it
docker pull localhost:5000/agent-zero:model-overrides
```

### Option C: Copy Docker Image Directly

```bash
# Copy image to system's docker images directory (requires root)
sudo mkdir -p /var/lib/docker/images/local
docker save agent-zero:model-overrides > /tmp/agent-zero-model-overrides.tar
sudo cp /tmp/agent-zero-model-overrides.tar /var/lib/docker/images/local/

# Users can load it
docker load -i /var/lib/docker/images/local/agent-zero-model-overrides.tar
```

## Development Mode (No Rebuild Needed)

For development, you can mount the changed files directly without rebuilding:

```bash
# Use the dev profile in docker-compose
docker-compose -f docker-compose.local.yml --profile dev up -d agent-zero-dev

# Or run directly with docker
docker run -d \
  -v $(pwd)/python/helpers/subagents.py:/a0/python/helpers/subagents.py:ro \
  -v $(pwd)/python/extensions/agent_init/_15_load_profile_settings.py:/a0/python/extensions/agent_init/_15_load_profile_settings.py:ro \
  -v $(pwd)/agents:/a0/agents:ro \
  -v $(pwd)/webui/components/settings/agents:/a0/webui/components/settings/agents:ro \
  -v ./agent-zero-data:/a0 \
  -p 50080:80 \
  --name agent-zero-dev \
  agent0ai/agent-zero:latest
```

## Verifying Model Overrides Work

1. Start the container
2. Open the UI at http://localhost:50080
3. Click the "Agents" button in the sidebar
4. Edit the "Developer" agent profile
5. Set a custom chat model (e.g., different provider or temperature)
6. Save the changes
7. Use the "Call Subordinate" tool with profile "developer"
8. Check the logs - you should see:
   > "Agent A1 (developer): Model overrides applied: chat=provider/model"

## Troubleshooting

### Permission Denied on Volume

```bash
# Fix ownership
sudo chown -R $(id -u):$(id -g) ./agent-zero-data

# Or use named volumes instead of bind mounts
docker volume create agent-zero-data
docker run -v agent-zero-data:/a0 agent-zero:model-overrides
```

### Port Already in Use

```bash
# Find what's using port 50080
sudo lsof -i :50080

# Change the host port in docker-compose.local.yml
ports:
  - "50081:80"  # Use 50081 instead of 50080
```

### Container Exits Immediately

```bash
# Check logs
docker logs agent-zero-local

# Run interactively to debug
docker run -it --rm agent-zero:model-overrides /bin/bash
```

## Environment Variables

You can pass API keys via environment variables:

```yaml
environment:
  - API_KEY_OPENAI=${API_KEY_OPENAI}
  - API_KEY_ANTHROPIC=${API_KEY_ANTHROPIC}
  - API_KEY_OPENROUTER=${API_KEY_OPENROUTER}
```

Or use a `.env` file:

```bash
# .env file
API_KEY_OPENAI=sk-...
API_KEY_ANTHROPIC=sk-ant-...
```

Then run:
```bash
docker-compose -f docker-compose.local.yml --env-file .env up -d
```
