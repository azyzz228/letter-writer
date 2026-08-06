import {defineConfig, devices} from "@playwright/test"

export default defineConfig({
  testDir: "./test/e2e",
  fullyParallel: false,
  workers: 1,
  reporter: "line",
  use: {
    baseURL: "http://127.0.0.1:4010",
    trace: "retain-on-failure",
  },
  projects: [
    {name: "chromium", use: {...devices["Desktop Chrome"]}},
  ],
  webServer: {
    command: "cd .. && PORT=4010 mix phx.server",
    url: "http://127.0.0.1:4010",
    reuseExistingServer: true,
    timeout: 120000,
  },
})
