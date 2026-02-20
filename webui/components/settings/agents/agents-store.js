import { createStore } from "/js/AlpineStore.js";
import * as api from "/js/api.js";
import * as modals from "/js/modals.js";
import * as notifications from "/components/notifications/notification-store.js";

const listModal = "settings/agents/agents-list.html";
const editModal = "settings/agents/agent-edit.html";

// Default empty model override
const defaultModelOverride = {
  provider: "",
  name: "",
  api_base: "",
  ctx_length: "",
  vision: null,
  limit_requests: "",
  limit_input: "",
  limit_output: "",
  kwargs: "",
};

// define the model object holding data and functions
const model = {
  agentsList: [],
  selectedAgent: null,
  isLoading: false,
  chatProviders: [],
  embeddingProviders: [],

  async openAgentsModal() {
    await this.loadAgentsList();
    await this.loadProviders();
    await modals.openModal(listModal);
  },

  async openEditModal(name) {
    this.isLoading = true;
    try {
      await this.loadAgentForEdit(name);
      await modals.openModal(editModal);
    } finally {
      this.isLoading = false;
    }
  },

  async cancelEdit() {
    await modals.closeModal(editModal);
    this.selectedAgent = null;
  },

  async confirmEdit() {
    const agent = await this.saveSelectedAgent();
    if (agent) {
      await this.loadAgentsList();
      await modals.closeModal(editModal);
      this.selectedAgent = null;
    }
  },

  async loadProviders() {
    try {
      const response = await api.callJsonApi("/settings_get", {});
      if (response?.settings?.additional) {
        this.chatProviders = response.settings.additional.chat_providers || [];
        this.embeddingProviders = response.settings.additional.embedding_providers || [];
      }
    } catch (error) {
      console.error("Error loading providers:", error);
    }
  },

  async loadAgentsList() {
    this.isLoading = true;
    try {
      const response = await api.callJsonApi("subagents", {
        action: "list",
      });
      this.agentsList = response.data || [];
    } catch (error) {
      console.error("Error loading agents list:", error);
      notifications.toastFrontendError(
        "Error loading agents list: " + error,
        "Error",
        5,
        "agents",
        notifications.NotificationPriority.NORMAL,
        true
      );
    } finally {
      this.isLoading = false;
    }
  },

  async loadAgentForEdit(name) {
    try {
      const response = await api.callJsonApi("subagents", {
        action: "load",
        name: name,
      });
      
      const agentData = response.data || {};
      
      // Ensure model overrides exist with proper structure
      this.selectedAgent = {
        ...agentData,
        chat_model: this._normalizeModelOverride(agentData.chat_model),
        utility_model: this._normalizeModelOverride(agentData.utility_model),
        embeddings_model: this._normalizeModelOverride(agentData.embeddings_model),
        browser_model: this._normalizeModelOverride(agentData.browser_model),
      };
    } catch (error) {
      console.error("Error loading agent:", error);
      notifications.toastFrontendError(
        "Error loading agent: " + error,
        "Error",
        5,
        "agents",
        notifications.NotificationPriority.NORMAL,
        true
      );
    }
  },

  _normalizeModelOverride(override) {
    if (!override) {
      return { ...defaultModelOverride };
    }
    return {
      ...defaultModelOverride,
      ...override,
    };
  },

  async saveSelectedAgent() {
    try {
      // Prepare data - convert empty strings to null and kwargs to object
      const data = this._prepareAgentDataForSave(this.selectedAgent);

      const response = await api.callJsonApi("subagents", {
        action: "save",
        name: this.selectedAgent.name,
        data: data,
      });

      if (response.ok) {
        notifications.toastFrontendSuccess(
          "Agent saved successfully",
          "Agent saved",
          3,
          "agents",
          notifications.NotificationPriority.NORMAL,
          true
        );
        return response.data;
      } else {
        notifications.toastFrontendError(
          response.error || "Error saving agent",
          "Error saving agent",
          5,
          "agents",
          notifications.NotificationPriority.NORMAL,
          true
        );
        return null;
      }
    } catch (error) {
      console.error("Error saving agent:", error);
      notifications.toastFrontendError(
        "Error saving agent: " + error,
        "Error saving agent",
        5,
        "agents",
        notifications.NotificationPriority.NORMAL,
        true
      );
      return null;
    }
  },

  _prepareAgentDataForSave(agent) {
    const data = { ...agent };

    // Clean up model overrides - remove empty values and convert types
    const modelFields = ["chat_model", "utility_model", "embeddings_model", "browser_model"];
    
    for (const field of modelFields) {
      if (data[field]) {
        data[field] = this._cleanModelOverride(data[field]);
      }
    }

    // Remove internal fields
    for (const key of Object.keys(data)) {
      if (key.startsWith("_")) {
        delete data[key];
      }
    }

    return data;
  },

  _cleanModelOverride(override) {
    if (!override) return null;

    const cleaned = {};
    
    // Only include non-empty values
    if (override.provider) cleaned.provider = override.provider;
    if (override.name) cleaned.name = override.name;
    if (override.api_base) cleaned.api_base = override.api_base;
    if (override.ctx_length !== "" && override.ctx_length !== null && override.ctx_length !== undefined) {
      cleaned.ctx_length = parseInt(override.ctx_length, 10) || override.ctx_length;
    }
    if (override.vision !== null && override.vision !== undefined) {
      cleaned.vision = override.vision;
    }
    if (override.limit_requests !== "" && override.limit_requests !== null && override.limit_requests !== undefined) {
      cleaned.limit_requests = parseInt(override.limit_requests, 10) || override.limit_requests;
    }
    if (override.limit_input !== "" && override.limit_input !== null && override.limit_input !== undefined) {
      cleaned.limit_input = parseInt(override.limit_input, 10) || override.limit_input;
    }
    if (override.limit_output !== "" && override.limit_output !== null && override.limit_output !== undefined) {
      cleaned.limit_output = parseInt(override.limit_output, 10) || override.limit_output;
    }
    
    // Parse kwargs from string to object
    if (override.kwargs && typeof override.kwargs === "string" && override.kwargs.trim()) {
      try {
        // Try to parse as JSON first
        cleaned.kwargs = JSON.parse(override.kwargs);
      } catch (e) {
        // If not valid JSON, treat as key=value pairs
        const kwargsObj = {};
        const lines = override.kwargs.split("\n");
        for (const line of lines) {
          const [key, ...valueParts] = line.split("=");
          if (key && valueParts.length > 0) {
            const value = valueParts.join("=").trim();
            // Try to parse as number/boolean
            if (value === "true") kwargsObj[key.trim()] = true;
            else if (value === "false") kwargsObj[key.trim()] = false;
            else if (!isNaN(Number(value))) kwargsObj[key.trim()] = Number(value);
            else kwargsObj[key.trim()] = value;
          }
        }
        if (Object.keys(kwargsObj).length > 0) {
          cleaned.kwargs = kwargsObj;
        }
      }
    } else if (override.kwargs && typeof override.kwargs === "object") {
      cleaned.kwargs = override.kwargs;
    }

    // Return null if no fields are set
    return Object.keys(cleaned).length > 0 ? cleaned : null;
  },

  async deleteAgent(name) {
    // show confirmation dialog before proceeding
    const confirmed = window.confirm(
      `Are you sure you want to permanently delete the agent profile "${name}"? This action is irreversible.`
    );
    if (!confirmed) return;

    try {
      const response = await api.callJsonApi("subagents", {
        action: "delete",
        name: name,
      });

      if (response.ok) {
        notifications.toastFrontendSuccess(
          "Agent deleted successfully",
          "Agent deleted",
          3,
          "agents",
          notifications.NotificationPriority.NORMAL,
          true
        );
        await this.loadAgentsList();
      } else {
        notifications.toastFrontendError(
          response.error || "Error deleting agent",
          "Error deleting agent",
          5,
          "agents",
          notifications.NotificationPriority.NORMAL,
          true
        );
      }
    } catch (error) {
      console.error("Error deleting agent:", error);
      notifications.toastFrontendError(
        "Error deleting agent: " + error,
        "Error deleting agent",
        5,
        "agents",
        notifications.NotificationPriority.NORMAL,
        true
      );
    }
  },

  // Helper to get provider options for a model type
  getProviderOptions(modelType) {
    if (modelType === "embedding") {
      return this.embeddingProviders;
    }
    return this.chatProviders;
  },

  // Check if any model override is configured
  hasModelOverrides(agent) {
    if (!agent) return false;
    const modelFields = ["chat_model", "utility_model", "embeddings_model", "browser_model"];
    return modelFields.some(field => {
      const override = agent[field];
      if (!override) return false;
      return Object.values(override).some(v => v !== "" && v !== null && v !== undefined);
    });
  },
};

// convert it to alpine store
const store = createStore("agents", model);

// export for use in other files
export { store };
