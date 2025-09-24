import { defineConfig, devices } from '@playwright/test';
import * as dotenv from 'dotenv';

// Load environment variables
dotenv.config();

/**
 * See https://playwright.dev/docs/test-configuration
 */
export default defineConfig({
  testDir: './tests',

  // Run tests in files in parallel
  fullyParallel: true,

  // Fail the build on CI if you accidentally left test.only in the source code
  forbidOnly: !!process.env.CI,

  // Retry on CI only
  retries: process.env.CI ? 2 : 0,

  // Opt out of parallel tests on CI
  workers: process.env.CI ? 1 : undefined,

  // Reporter to use
  reporter: [
    ['html', { outputFolder: 'playwright-report', open: 'never' }],
    ['json', { outputFile: 'test-results/results.json' }],
    ['junit', { outputFile: 'test-results/junit.xml' }],
    ['list'],
  ],

  // Shared settings for all the projects below
  use: {
    // Base URL to use in actions like `await page.goto('/')`
    baseURL: process.env.BASE_URL || 'http://localhost:3002',

    // Collect trace when retrying the failed test
    trace: 'on-first-retry',

    // Screenshot on failure
    screenshot: 'only-on-failure',

    // Video on failure
    video: 'retain-on-failure',

    // Maximum time each action can take
    actionTimeout: 15000,

    // Navigation timeout
    navigationTimeout: 30000,

    // Accept downloads
    acceptDownloads: true,

    // Ignore HTTPS errors (useful for local development)
    ignoreHTTPSErrors: true,

    // Viewport size
    viewport: { width: 1920, height: 1080 },

    // Locale and timezone for consistency
    locale: 'en-US',
    timezoneId: 'UTC',
  },

  // Configure projects for major browsers
  projects: [
    {
      name: 'chromium',
      use: {
        ...devices['Desktop Chrome'],
        // Custom launch options for Docker environment
        launchOptions: {
          args: [
            '--disable-dev-shm-usage',
            '--no-sandbox',
            '--disable-setuid-sandbox',
            '--disable-gpu',
          ],
        },
      },
    },

    {
      name: 'firefox',
      use: {
        ...devices['Desktop Firefox'],
        launchOptions: {
          firefoxUserPrefs: {
            'media.navigator.streams.fake': true,
            'media.navigator.permission.disabled': true,
          },
        },
      },
    },

    {
      name: 'webkit',
      use: { ...devices['Desktop Safari'] },
    },

    // Mobile viewports
    {
      name: 'mobile',
      use: { ...devices['iPhone 13'] },
    },

    {
      name: 'tablet',
      use: { ...devices['iPad (gen 7)'] },
    },
  ],

  // Run your local dev server before starting the tests
  // Disabled in Docker as services are already running
  webServer: process.env.CI || process.env.DOCKER ? undefined : {
    command: 'cd .. && npm run dev',
    url: 'http://localhost:3002',
    timeout: 120 * 1000,
    reuseExistingServer: !process.env.CI,
  },

  // Global timeout for the whole test run
  globalTimeout: process.env.CI ? 60 * 60 * 1000 : undefined, // 1 hour on CI

  // Timeout for each test
  timeout: 60 * 1000, // 1 minute

  // Expect timeout
  expect: {
    timeout: 10 * 1000, // 10 seconds
  },

  // Output folder for test artifacts
  outputDir: 'test-results',
});