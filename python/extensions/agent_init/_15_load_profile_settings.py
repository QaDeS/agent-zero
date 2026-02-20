from initialize import initialize_agent
from python.helpers import dirty_json, files, subagents, projects
from python.helpers.extension import Extension
import models


class LoadProfileSettings(Extension):

    async def execute(self, **kwargs) -> None:

        if not self.agent or not self.agent.config.profile:
            return

        config_files = subagents.get_paths(self.agent, "settings.json", include_default=False)

        settings_override = {}
        for settings_path in config_files:
            if files.exists(settings_path):
                try:
                    override_settings_str = files.read_file(settings_path)
                    override_settings = dirty_json.try_parse(override_settings_str)
                    if isinstance(override_settings, dict):
                        settings_override.update(override_settings)
                    else:
                        raise Exception(
                            f"Subordinate settings in {settings_path} must be a JSON object."
                        )
                except Exception as e:
                    self.agent.context.log.log(
                        type="error",
                        content=(
                            f"Error loading subordinate settings from {settings_path} for "
                            f"profile '{self.agent.config.profile}': {e}"
                        ),
                    )

        if settings_override:
            # Preserve the original memory_subdir unless it's explicitly overridden
            current_memory_subdir = self.agent.config.memory_subdir
            new_config = initialize_agent(override_settings=settings_override)
            if (
                "agent_memory_subdir" not in settings_override
                and current_memory_subdir != "default"
            ):
                new_config.memory_subdir = current_memory_subdir
            self.agent.config = new_config

        # Apply model overrides from agent.json (SubAgent configuration)
        await self._apply_model_overrides()

    async def _apply_model_overrides(self):
        """Apply model overrides from the agent's SubAgent configuration."""
        try:
            from python.helpers import projects

            # Get project name if available
            project_name = projects.get_context_project_name(self.agent.context)

            # Load agent data (merged from default, user, and project sources)
            agent_data = subagents.load_agent_data(self.agent.config.profile, project_name)

            overrides_applied = []

            # Apply chat model override
            if agent_data.chat_model and self._has_override_values(agent_data.chat_model):
                self.agent.config.chat_model = self._merge_model_config(
                    self.agent.config.chat_model, agent_data.chat_model
                )
                overrides_applied.append(f"chat={self.agent.config.chat_model.provider}/{self.agent.config.chat_model.name}")

            # Apply utility model override
            if agent_data.utility_model and self._has_override_values(agent_data.utility_model):
                self.agent.config.utility_model = self._merge_model_config(
                    self.agent.config.utility_model, agent_data.utility_model
                )
                overrides_applied.append(f"utility={self.agent.config.utility_model.provider}/{self.agent.config.utility_model.name}")

            # Apply embeddings model override
            if agent_data.embeddings_model and self._has_override_values(agent_data.embeddings_model):
                self.agent.config.embeddings_model = self._merge_embedding_config(
                    self.agent.config.embeddings_model, agent_data.embeddings_model
                )
                overrides_applied.append(f"embeddings={self.agent.config.embeddings_model.provider}/{self.agent.config.embeddings_model.name}")

            # Apply browser model override
            if agent_data.browser_model and self._has_override_values(agent_data.browser_model):
                self.agent.config.browser_model = self._merge_model_config(
                    self.agent.config.browser_model, agent_data.browser_model
                )
                overrides_applied.append(f"browser={self.agent.config.browser_model.provider}/{self.agent.config.browser_model.name}")

            # Log if any overrides were applied
            if overrides_applied:
                self.agent.context.log.log(
                    type="info",
                    content=(
                        f"Agent {self.agent.agent_name} ({self.agent.config.profile}): "
                        f"Model overrides applied: {', '.join(overrides_applied)}"
                    ),
                )

        except Exception as e:
            self.agent.context.log.log(
                type="error",
                content=(
                    f"Error applying model overrides for profile "
                    f"'{self.agent.config.profile}': {e}"
                ),
            )

    def _has_override_values(self, override: subagents.ModelOverride) -> bool:
        """Check if the model override has any non-null values set."""
        if override is None:
            return False
        return any(
            value is not None and value != "" and value != {}
            for value in [
                override.provider,
                override.name,
                override.api_base,
                override.ctx_length,
                override.vision,
                override.limit_requests,
                override.limit_input,
                override.limit_output,
                override.kwargs,
            ]
        )

    def _merge_model_config(
        self,
        base_config: models.ModelConfig,
        override: subagents.ModelOverride,
    ) -> models.ModelConfig:
        """Merge model override into base model config."""
        # Merge kwargs
        merged_kwargs = dict(base_config.kwargs)
        if override.kwargs:
            merged_kwargs.update(override.kwargs)

        return models.ModelConfig(
            type=base_config.type,
            provider=override.provider if override.provider is not None else base_config.provider,
            name=override.name if override.name is not None else base_config.name,
            api_base=override.api_base if override.api_base is not None else base_config.api_base,
            ctx_length=override.ctx_length if override.ctx_length is not None else base_config.ctx_length,
            vision=override.vision if override.vision is not None else base_config.vision,
            limit_requests=override.limit_requests if override.limit_requests is not None else base_config.limit_requests,
            limit_input=override.limit_input if override.limit_input is not None else base_config.limit_input,
            limit_output=override.limit_output if override.limit_output is not None else base_config.limit_output,
            kwargs=merged_kwargs,
        )

    def _merge_embedding_config(
        self,
        base_config: models.ModelConfig,
        override: subagents.ModelOverride,
    ) -> models.ModelConfig:
        """Merge model override into embedding model config."""
        # Merge kwargs
        merged_kwargs = dict(base_config.kwargs)
        if override.kwargs:
            merged_kwargs.update(override.kwargs)

        return models.ModelConfig(
            type=models.ModelType.EMBEDDING,
            provider=override.provider if override.provider is not None else base_config.provider,
            name=override.name if override.name is not None else base_config.name,
            api_base=override.api_base if override.api_base is not None else base_config.api_base,
            ctx_length=override.ctx_length if override.ctx_length is not None else base_config.ctx_length,
            vision=False,  # Embeddings don't support vision
            limit_requests=override.limit_requests if override.limit_requests is not None else base_config.limit_requests,
            limit_input=override.limit_input if override.limit_input is not None else base_config.limit_input,
            limit_output=override.limit_output if override.limit_output is not None else base_config.limit_output,
            kwargs=merged_kwargs,
        )
