import { Page, Locator } from '@playwright/test';
import { BasePage } from './base.page';

export class LoginPage extends BasePage {
  readonly emailInput: Locator;
  readonly passwordInput: Locator;
  readonly loginButton: Locator;
  readonly rememberMeCheckbox: Locator;
  readonly errorMessage: Locator;
  readonly logoutLink: Locator;

  constructor(page: Page) {
    super(page);
    this.emailInput = page.locator('input[name="email"], input[type="email"], #email');
    this.passwordInput = page.locator('input[name="password"], input[type="password"], #password');
    this.loginButton = page.locator('button[type="submit"]:has-text("Login"), input[type="submit"][value*="Login"]');
    this.rememberMeCheckbox = page.locator('input[name="remember_me"], #remember_me');
    this.errorMessage = page.locator('.alert-danger, .error-message, .flash-error');
    this.logoutLink = page.locator('a:has-text("Logout"), button:has-text("Logout")');
  }

  /**
   * Navigate to login page
   */
  async goto() {
    await this.navigate('/login');
  }

  /**
   * Perform login
   */
  async login(email: string, password: string, rememberMe: boolean = false) {
    await this.fillField(this.emailInput, email);
    await this.fillField(this.passwordInput, password);

    if (rememberMe) {
      await this.rememberMeCheckbox.check();
    }

    // Wait for form to be ready
    await this.page.waitForTimeout(500);

    await this.loginButton.click();

    // Wait for navigation or error
    await Promise.race([
      this.page.waitForURL('**/dashboard', { timeout: 10000 }),
      this.page.waitForURL('**/invoices', { timeout: 10000 }),
      this.errorMessage.waitFor({ state: 'visible', timeout: 10000 })
    ]).catch(() => {});
  }

  /**
   * Quick login with default test credentials
   */
  async quickLogin() {
    await this.goto();
    await this.login('admin@example.com', 'password123');
  }

  /**
   * Check if user is logged in
   */
  async isLoggedIn(): Promise<boolean> {
    return await this.logoutLink.isVisible({ timeout: 5000 }).catch(() => false);
  }

  /**
   * Logout
   */
  async logout() {
    if (await this.isLoggedIn()) {
      await this.logoutLink.click();
      await this.page.waitForURL('**/login', { timeout: 10000 });
    }
  }

  /**
   * Get error message
   */
  async getErrorMessage(): Promise<string | null> {
    if (await this.errorMessage.isVisible()) {
      return await this.errorMessage.textContent();
    }
    return null;
  }
}