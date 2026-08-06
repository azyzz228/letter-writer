import {expect, test} from "@playwright/test"

test("a guest can write, seal, unlock, refresh, inspect, and revoke a letter", async ({page}) => {
  await page.goto("/write")
  await expect(page.locator("#seal-letter-form")).toBeVisible()

  await page.getByLabel("To").fill("My dearest")
  await page.getByLabel("From").fill("Always yours")
  await page.getByLabel("A small title (optional)").fill("Across the same sky")
  await page.locator(".ProseMirror").fill("No distance can make these words less true.")
  await page.getByLabel("Letter password", {exact: true}).fill("quiet-moon-paper")
  await page.getByLabel("Confirm password").fill("quiet-moon-paper")
  await page.getByLabel("This letter never expires").check()
  await page.locator("#seal-letter-button").click()

  await expect(page.locator("#sealed-success")).toBeVisible()
  const publicUrl = (await page.locator("#public-letter-url").textContent()).trim()
  const managementUrl = (await page.locator("#management-letter-url").textContent()).trim()

  await page.goto(publicUrl)
  await expect(page.locator("#unlock-letter-form")).toBeVisible()
  await page.getByLabel("Letter password").fill("quiet-moon-paper")
  await page.locator("#unlock-letter-button").click()
  await expect(page.locator("#opened-letter")).toContainText("Across the same sky")

  await page.reload()
  await expect(page.locator("#opened-letter")).toBeVisible()

  await page.goto(managementUrl)
  await expect(page.locator("#manage-letter")).toBeVisible()
  await expect(page.locator("#manage-letter")).toContainText("Openings used")

  page.once("dialog", dialog => dialog.accept())
  await page.getByRole("button", {name: "Recall permanently"}).click()
  await expect(page.locator(".status-revoked")).toBeVisible()

  await page.goto(publicUrl)
  await expect(page.locator("#letter-unavailable")).toBeVisible()
})
