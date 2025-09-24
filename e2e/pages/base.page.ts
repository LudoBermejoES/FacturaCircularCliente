import { Page, Locator } from '@playwright/test';

export class BasePage {
  readonly page: Page;

  constructor(page: Page) {
    this.page = page;
  }

  /**
   * Navigate to a specific path
   */
  async navigate(path: string) {
    await this.page.goto(path);
    await this.page.waitForLoadState('networkidle');
  }

  /**
   * Wait for an element to be visible
   */
  async waitForElement(selector: string, timeout: number = 30000) {
    await this.page.waitForSelector(selector, { state: 'visible', timeout });
  }

  /**
   * Check if an element exists
   */
  async elementExists(selector: string): Promise<boolean> {
    return await this.page.locator(selector).count() > 0;
  }

  /**
   * Get text content of an element
   */
  async getTextContent(selector: string): Promise<string | null> {
    return await this.page.locator(selector).textContent();
  }

  /**
   * Click an element with retry logic
   */
  async clickWithRetry(locator: Locator, retries: number = 3) {
    for (let i = 0; i < retries; i++) {
      try {
        await locator.click({ timeout: 5000 });
        break;
      } catch (error) {
        if (i === retries - 1) throw error;
        await this.page.waitForTimeout(1000);
      }
    }
  }

  /**
   * Fill form field with clear first
   */
  async fillField(locator: Locator, value: string) {
    await locator.click();
    await locator.clear();
    await locator.fill(value);
  }

  /**
   * Wait for API response
   */
  async waitForAPIResponse(urlPattern: string | RegExp) {
    return await this.page.waitForResponse(
      response =>
        (typeof urlPattern === 'string'
          ? response.url().includes(urlPattern)
          : urlPattern.test(response.url())) &&
        response.status() === 200
    );
  }

  /**
   * Take a screenshot with a descriptive name
   */
  async screenshot(name: string) {
    await this.page.screenshot({
      path: `test-results/screenshots/${name}-${Date.now()}.png`,
      fullPage: true,
    });
  }

  /**
   * Get flash message content
   */
  async getFlashMessage(): Promise<string | null> {
    const flash = this.page.locator('.flash-message, .alert');
    if (await flash.isVisible()) {
      return await flash.textContent();
    }
    return null;
  }

  /**
   * Close flash messages
   */
  async closeFlashMessages() {
    const closeButtons = this.page.locator('.flash-message button.close, .alert button.close');
    const count = await closeButtons.count();
    for (let i = 0; i < count; i++) {
      await closeButtons.nth(i).click();
    }
  }

  /**
   * Wait for page to be ready (no spinners, loaders)
   */
  async waitForPageReady() {
    // Wait for common loading indicators to disappear
    await this.page.waitForSelector('.spinner, .loading, .loader', { state: 'hidden', timeout: 5000 }).catch(() => {});
    await this.page.waitForLoadState('networkidle');
  }
}