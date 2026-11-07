const { test, expect } = require('@playwright/test');

test('guide loads without browser errors or broken local assets', async ({ page }) => {
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  page.on('response', response => {
    if (response.url().startsWith('http://127.0.0.1:4173') && !response.ok()) {
      errors.push(`${response.status()} ${response.url()}`);
    }
  });
  await page.goto('/');
  await expect(page).toHaveTitle('PixelPaper — Guida completa');
  await expect(page.getByRole('heading', { level: 1 })).toHaveText('Guida a PixelPaper');
  const broken = await page.locator('img').evaluateAll(async images => {
    await Promise.all(images.map(image => image.decode().catch(() => {})));
    return images.filter(image => !image.complete || !image.naturalWidth).map(image => image.src);
  });
  expect(broken).toEqual([]);
  expect(errors).toEqual([]);
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
});

test('navigation, PDF quality guidance and screenshot controls work', async ({ page }, testInfo) => {
  await page.goto('/');
  await page.getByRole('link', { name: 'Crea un PDF dalle foto' }).click();
  await expect(page).toHaveURL(/#galleria$/);
  await expect(page.locator('#galleria')).toContainText('Crea PDF');
  await expect(page.locator('#galleria')).toContainText('Originale');
  await expect(page.locator('#galleria')).toContainText('Compatto');
  if (testInfo.project.name === 'mobile') {
    await page.getByRole('button', { name: 'Indice', exact: true }).click();
    await expect(page.locator('#toc')).toBeVisible();
    await page.locator('#toc').getByRole('link', { name: 'Editor delle pagine' }).click();
    await expect(page).toHaveURL(/#editor$/);
    await expect(page.locator('#toc')).toBeHidden();
  }
  await page.locator('#shots-track').scrollIntoViewIfNeeded();
  await page.getByRole('button', { name: 'Schermata successiva' }).click();
  await expect.poll(() => page.locator('#shots-track').evaluate(track => track.scrollLeft)).toBeGreaterThan(0);
  await expect(page.locator('#privacy')).toContainText('non richiede accesso diretto');
  await expect(page.getByRole('link', { name: 'Scarica dal Play Store' })).toHaveAttribute('href', /play\.google\.com/);
});

test('all internal anchors resolve and content stays visible with reduced motion', async ({ page }) => {
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await page.goto('/');
  const missing = await page.locator('a[href^="#"]').evaluateAll(links => links
    .map(link => link.getAttribute('href'))
    .filter(href => href.length > 1 && !document.getElementById(href.slice(1))));
  expect(missing).toEqual([]);
  await page.locator('#domande').scrollIntoViewIfNeeded();
  await expect(page.locator('#domande h2')).toBeVisible();
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
});
