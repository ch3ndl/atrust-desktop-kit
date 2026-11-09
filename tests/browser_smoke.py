# SPDX-License-Identifier: MIT
"""Offline browser test: local synthetic form, no VPN or real credentials."""
import sys
from pathlib import Path
from urllib.parse import quote
from selenium import webdriver
from selenium.webdriver.common.by import By
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'runtime'))
from helper import submit_once, logged_in

options = webdriver.ChromeOptions()
options.binary_location = '/usr/bin/chromium'
for flag in ('--headless=new', '--no-sandbox', '--disable-dev-shm-usage'):
    options.add_argument(flag)
driver = webdriver.Chrome(service=webdriver.ChromeService('/usr/bin/chromedriver'), options=options)
try:
    html = '''<html><body><input style="display:none" type="text"><input id="user" type="text">
    <input id="pw" type="password" value="previous-example"><label><input id="consent" type="checkbox">Accept</label>
    <button id="login">Log In</button><script>
    window.submissions=0; window.model='previous-example';
    document.querySelector('#pw').addEventListener('input',e=>window.model=e.target.value);
    document.querySelector('#login').onclick=()=>{
      window.submissions++;
      window.valid=document.querySelector('#user').value==='sample-user' &&
      window.model==='example-ONLY_123' && document.querySelector('#consent').checked;
      if(window.valid){ location.hash='/app_center'; document.body.innerHTML='Workspace'; }
    };</script></body></html>'''
    driver.get('data:text/html;charset=utf-8,' + quote(html))
    assert submit_once(driver, 'sample-user', 'example-ONLY_123')
    assert driver.execute_script('return window.valid')
    assert driver.execute_script('return window.submissions') == 1
    assert logged_in(driver)
    print('PASS: reactive form input, hidden field exclusion, consent, single submit, workspace detection')
finally:
    driver.quit()
