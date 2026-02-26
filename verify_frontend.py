
import asyncio
from playwright.async_api import async_playwright, expect

async def verify_new_features():
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        page = await browser.new_page()

        # Navigate to frontend
        try:
            await page.goto("http://localhost:5173", timeout=10000)
        except Exception as e:
            print(f"Failed to load page: {e}")
            await browser.close()
            return

        # Wait for input
        await page.wait_for_selector('textarea#news-input')

        # 1. Test Search and History
        # Submit first search
        await page.fill('textarea#news-input', 'This is a test search for history 1')
        await page.click('button#check-btn')

        # Wait for result
        await page.wait_for_selector('text=Analysis Result')

        # Check if history item appears (might need a refresh or just wait if implemented with state)
        # In our implementation, we update submissionCount which triggers history refresh
        try:
            await page.wait_for_selector('button[title="This is a test search for history 1"]', timeout=5000)
            print("History item 1 found")
        except:
            print("History item 1 not found immediately")

        # Submit second search
        # Clear input first (React state binding might require filling empty then new)
        await page.fill('textarea#news-input', '')
        await page.fill('textarea#news-input', 'This is a test search for history 2')
        await page.click('button#check-btn')

        await page.wait_for_timeout(1000) # Wait for processing

        try:
            await page.wait_for_selector('button[title="This is a test search for history 2"]', timeout=5000)
            print("History item 2 found")
        except:
            print("History item 2 not found immediately")

        # Click history item 1 to repopulate
        await page.click('button[title="This is a test search for history 1"]')

        # Check if input is populated
        input_value = await page.input_value('textarea#news-input')
        if input_value == 'This is a test search for history 1':
            print("History click populated input correctly")
        else:
            print(f"History click failed. Input: {input_value}")

        # 2. Test Copy Button
        # The result card should be visible
        # Check if copy button exists
        copy_btn = page.locator('button[title="Copy summary to clipboard"]')
        if await copy_btn.count() > 0:
            print("Copy button found")
            # We can't easily test clipboard content in headless without permissions,
            # but we can click it to ensure no errors
            await copy_btn.click()
            print("Copy button clicked")
        else:
            print("Copy button not found")

        # Take screenshot
        await page.screenshot(path="verification_screenshot.png", full_page=True)
        print("Screenshot taken")

        await browser.close()

if __name__ == "__main__":
    asyncio.run(verify_new_features())
