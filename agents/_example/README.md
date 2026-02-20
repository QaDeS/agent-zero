# Agent Role Model Overrides

This feature allows agent roles (profiles) to override the models they use, independent of the global settings.

## Overview

Each agent role can now specify its own model configurations in its `agent.json` file. This is useful when:

- Different roles need different model capabilities (e.g., coding vs research)
- You want to use a cheaper model for simple tasks and a more capable model for complex ones
- Certain roles need specific model parameters (e.g., temperature, context length)

## Configuration

Add model override sections to your `agent.json` file:

```json
{
  "title": "My Custom Agent",
  "description": "Agent with custom model configuration",
  "context": "Use this agent for...",
  "enabled": true,
  
  "chat_model": {
    "provider": "openrouter",
    "name": "anthropic/claude-3.5-sonnet",
    "temperature": 0.2
  },
  
  "utility_model": {
    "provider": "openai",
    "name": "gpt-4o-mini"
  },
  
  "embeddings_model": {
    "provider": "huggingface",
    "name": "sentence-transformers/all-MiniLM-L6-v2"
  },
  
  "browser_model": {
    "provider": "openrouter",
    "name": "anthropic/claude-3-haiku",
    "vision": true
  }
}
```

## Available Fields

Each model override supports the following fields:

### Common Fields

| Field | Type | Description |
|-------|------|-------------|
| `provider` | string | Model provider (e.g., "openai", "anthropic", "openrouter") |
| `name` | string | Model name/identifier |
| `api_base` | string | Custom API base URL |
| `limit_requests` | integer | Rate limit: requests per minute |
| `limit_input` | integer | Rate limit: input tokens per minute |
| `limit_output` | integer | Rate limit: output tokens per minute |
| `kwargs` | object | Additional provider-specific parameters |

### Chat Model & Browser Model Fields

| Field | Type | Description |
|-------|------|-------------|
| `ctx_length` | integer | Context window size in tokens |
| `vision` | boolean | Whether the model supports vision |

## Partial Overrides

You don't need to specify all fields. Unspecified fields will use the global default:

```json
{
  "chat_model": {
    "temperature": 0.2
  }
}
```

This only overrides the temperature parameter, keeping everything else from the global config.

## Merging Behavior

When an agent role is loaded:

1. Global settings are applied first
2. `settings.json` overrides are applied (if present)
3. Model overrides from `agent.json` are applied last

Project-specific agent configurations (in `.a0proj/agents/`) override user configurations, which override default configurations.

## Example Configurations

### Developer Agent with Reasoning Model

```json
{
  "chat_model": {
    "provider": "openrouter",
    "name": "anthropic/claude-3.5-sonnet",
    "kwargs": {
      "temperature": 0.2
    }
  }
}
```

### Researcher Agent with Large Context

```json
{
  "chat_model": {
    "ctx_length": 200000,
    "kwargs": {
      "temperature": 0.7
    }
  }
}
```

### Cost-Optimized Agent

```json
{
  "chat_model": {
    "provider": "openai",
    "name": "gpt-4o-mini"
  },
  "utility_model": {
    "provider": "openai",
    "name": "gpt-4o-mini"
  }
}
```

## File Locations

Agent configurations can be placed in:

- `agents/<profile>/agent.json` - Default agent configurations
- `usr/agents/<profile>/agent.json` - User custom agent configurations
- `.a0proj/agents/<profile>/agent.json` - Project-specific agent configurations

Configurations are merged in order: default → user → project.
