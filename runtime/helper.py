# SPDX-License-Identifier: MIT
"""Independent Selenium login implementation; no upstream Python source vendored."""
import argparse
import logging
import os
import re
import shlex
import socket
import tempfile
import time
from urllib.parse import urlsplit

from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.common.keys import Keys

LOG = logging.getLogger("atrust-desktop-kit")


class AuthenticationRejected(RuntimeError):
    """Stop rather than repeatedly consuming the account's retry allowance."""


def options(raw):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--portal_address", required=True)
    parser.add_argument("--username")
    parser.add_argument("--password")
    parser.add_argument("--keepalive", type=int, default=200)
    parser.add_argument("--login_timeout", type=int, default=3600)
    args = parser.parse_args(shlex.split(raw))
    portal = urlsplit(args.portal_address)
    if portal.scheme not in ("http", "https") or not portal.hostname or portal.username or portal.password:
        raise ValueError("Provide an HTTP(S) portal URL without embedded credentials")
    if bool(args.username) != bool(args.password):
        raise ValueError("Provide both username and password, or neither for manual login")
    if args.keepalive < 0 or args.login_timeout <= 0:
        raise ValueError("Invalid login interval or timeout")
    return args


def logged_in(driver):
    # Login success needs an authenticated workspace and no visible password form.
    route = urlsplit(driver.current_url).fragment.lower()
    if "login" in route or "auth" in route:
        return False
    text = driver.find_element(By.TAG_NAME, "body").text
    return any(label in text for label in ("Workspace", "工作台", "应用中心"))


def rejection(driver):
    text = driver.find_element(By.TAG_NAME, "body").text
    patterns = (
        r"用户名或密码错误[^\n]*", r"账号已锁定[^\n]*", r"账户已锁定[^\n]*",
        r"账号已注销[^\n]*", r"会话劫持[^\n]*",
        r"(?:incorrect|invalid) (?:username|password|credentials)[^\n]*",
    )
    return any(re.search(pattern, text, re.IGNORECASE) for pattern in patterns)


def visible_fields(driver):
    candidates = [e for e in driver.find_elements(By.CSS_SELECTOR, "input")
                  if e.is_displayed() and e.is_enabled()]
    password = next((e for e in candidates if e.get_attribute("type") == "password"), None)
    username = next((e for e in candidates if e.get_attribute("type") in ("text", "email") and e != password), None)
    return (username, password) if username is not None and password is not None else None


def type_checked(field, value):
    # WebElement.clear() can desynchronize the portal's reactive form state.
    field.click()
    field.send_keys(Keys.CONTROL, "a")
    field.send_keys(Keys.BACKSPACE)
    time.sleep(0.3)
    for character in value:
        field.send_keys(character)
        time.sleep(0.08)
    time.sleep(0.3)
    if field.get_attribute("value") != value:
        raise AuthenticationRejected("Input verification failed; credentials were not submitted")


def submit_once(driver, username, password):
    fields = visible_fields(driver)
    if not fields:
        return False
    for field, value in zip(fields, (username, password)):
        type_checked(field, value)
    for checkbox in driver.find_elements(By.CSS_SELECTOR, "input[type=checkbox]"):
        if checkbox.is_enabled() and not checkbox.is_selected():
            labels = driver.execute_script("return Array.from(arguments[0].labels || [])", checkbox)
            target = next((e for e in [*labels, checkbox] if e.is_displayed()), None)
            if target is None:
                raise AuthenticationRejected("Consent checkbox needs manual interaction")
            target.click()
    buttons = [e for e in driver.find_elements(By.CSS_SELECTOR, "button")
               if e.is_displayed() and e.is_enabled() and e.text.strip().lower() in ("登录", "login", "log in")]
    if len(buttons) != 1:
        raise AuthenticationRejected("Ambiguous login button; nothing was submitted")
    if any(field.get_attribute("value") != value for field, value in zip(fields, (username, password))):
        raise AuthenticationRejected("Input changed before submit; nothing was submitted")
    buttons[0].click()
    LOG.info("Submitted one password authentication attempt")
    return True


def authenticate(driver, args):
    deadline = time.monotonic() + args.login_timeout
    submitted = False
    while time.monotonic() < deadline:
        if rejection(driver):
            raise AuthenticationRejected("Portal rejected authentication or revoked the session; inspect VNC. No retry.")
        if logged_in(driver):
            LOG.info("Authenticated workspace detected")
            return
        if args.username and not submitted:
            submitted = submit_once(driver, args.username, args.password)
        time.sleep(1)
    raise AuthenticationRejected("Authentication timed out; complete any required verification through VNC")


def wait_client(timeout=120):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        try:
            with socket.create_connection(("127.0.0.1", 54631), timeout=1):
                return
        except OSError:
            time.sleep(1)
    raise RuntimeError("aTrust client did not become ready")


def run(args):
    wait_client()
    # No Cookie/localStorage import: a newly created client gets a new login.
    with tempfile.TemporaryDirectory(prefix="atrust-desktop-profile-") as profile:
        chrome = webdriver.ChromeOptions()
        chrome.binary_location = "/usr/bin/chromium"
        for option in ("--no-sandbox", "--disable-dev-shm-usage", "--no-first-run", "--lang=zh-CN", f"--user-data-dir={profile}"):
            chrome.add_argument(option)
        driver = webdriver.Chrome(service=webdriver.ChromeService("/usr/bin/chromedriver"), options=chrome)
        try:
            portal = urlsplit(args.portal_address)
            origin = f"{portal.scheme}://{portal.netloc}"
            try:
                driver.execute_cdp_cmd("Browser.setPermission", {"permission": {"name": "loopback-network"}, "setting": "granted", "origin": origin})
            except Exception:
                LOG.warning("Browser could not grant loopback permission; use VNC if prompted")
            driver.get(args.portal_address)
            authenticate(driver, args)
            if args.keepalive == 0:
                return
            while True:
                time.sleep(args.keepalive)
                driver.get(args.portal_address)
                authenticate(driver, args)
        finally:
            driver.quit()


def main():
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    try:
        run(options(os.environ.get("ATRUST_OPTS", "")))
        return 0
    except KeyboardInterrupt:
        return 130
    except Exception as exc:
        # Exception strings/tracebacks can contain form values or tokens.
        LOG.error("Login helper stopped (%s). Inspect the VNC desktop; no automatic retry.", type(exc).__name__)
        return 2
