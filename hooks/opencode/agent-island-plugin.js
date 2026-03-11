/**
 * OpenCode plugin for agentch.
 *
 * Install:
 *   Copy this file to .opencode/plugins/agent-island-plugin.js
 *   Or symlink it:
 *     ln -s <path-to>/agent-island/hooks/opencode/agent-island-plugin.js \
 *            .opencode/plugins/agent-island-plugin.js
 */

import { createConnection } from "net";

const SOCKET_PATH = "/tmp/agent-island.sock";

function sendToIsland(action, message = "", agent = "OpenCode", { duration = 0, pid = 0, interactive = false } = {}) {
  return new Promise((resolve) => {
    try {
      const client = createConnection(SOCKET_PATH, () => {
        const payload = JSON.stringify({ action, message, agent, duration, pid, interactive });
        client.write(payload + "\n");
      });
      client.on("data", () => {
        client.end();
        resolve();
      });
      client.on("error", () => resolve());
      client.setTimeout(2000, () => {
        client.end();
        resolve();
      });
    } catch {
      resolve();
    }
  });
}

export const AgentIslandPlugin = async () => {
  return {
    event: async ({ event }) => {
      if (event.type === "session.idle") {
        await sendToIsland("show", "Your turn", "OpenCode", { pid: process.ppid, interactive: true });
      }
      // Dismiss when user submits a new message
      if (
        event.type === "message.updated" &&
        event.properties?.role === "user"
      ) {
        await sendToIsland("dismiss");
      }
    },
  };
};
