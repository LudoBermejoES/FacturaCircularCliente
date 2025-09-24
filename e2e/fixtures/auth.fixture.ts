import { test as base, Page } from '@playwright/test';
import { LoginPage } from '../pages/login.page';

// Define the authenticated page fixture
export const test = base.extend<{
  authenticatedPage: Page;
  loginPage: LoginPage;
}>({
  authenticatedPage: async ({ page }, use) => {
    // Perform authentication
    const loginPage = new LoginPage(page);
    await loginPage.quickLogin();

    // Use the authenticated page in the test
    await use(page);

    // Cleanup: logout after test
    await loginPage.logout();
  },

  loginPage: async ({ page }, use) => {
    const loginPage = new LoginPage(page);
    await use(loginPage);
  },
});

export { expect } from '@playwright/test';

/**
 * Helper function to authenticate a user
 */
export async function authenticateUser(
  page: Page,
  email: string = 'admin@example.com',
  password: string = 'password123'
) {
  const loginPage = new LoginPage(page);
  await loginPage.goto();
  await loginPage.login(email, password);
}

/**
 * Helper to create authenticated context
 */
export async function createAuthenticatedContext(browser: any) {
  const context = await browser.newContext();
  const page = await context.newPage();

  // Perform login
  await authenticateUser(page);

  // Save storage state
  await context.storageState({ path: 'auth.json' });

  return { context, page };
}

/**
 * Mock authentication for faster tests
 */
export async function mockAuthentication(page: Page) {
  // Set authentication cookies/tokens directly
  await page.context().addCookies([
    {
      name: '_factura_circular_session',
      value: 'mock_session_token',
      domain: 'localhost',
      path: '/',
      httpOnly: true,
      secure: false,
      sameSite: 'Lax',
    },
  ]);

  // Set localStorage items if needed
  await page.addInitScript(() => {
    localStorage.setItem('auth_token', 'mock_jwt_token');
    localStorage.setItem('user_id', '1');
    localStorage.setItem('user_role', 'admin');
    localStorage.setItem('company_id', '1');
  });
}

/**
 * Test user data
 */
export const testUsers = {
  admin: {
    email: 'admin@example.com',
    password: 'password123',
    role: 'admin',
    companyId: 1,
  },
  manager: {
    email: 'manager@example.com',
    password: 'password123',
    role: 'manager',
    companyId: 1,
  },
  viewer: {
    email: 'viewer@example.com',
    password: 'password123',
    role: 'viewer',
    companyId: 1,
  },
  user: {
    email: 'user@example.com',
    password: 'password123',
    role: 'user',
    companyId: 2,
  },
};