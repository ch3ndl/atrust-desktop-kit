# SPDX-License-Identifier: MIT
import sys
import unittest
from pathlib import Path
from unittest.mock import Mock, patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "runtime"))
import helper


class HelperTests(unittest.TestCase):
    def test_quoted_password_is_not_reinterpreted(self):
        args = helper.options('--portal_address="https://vpn.example.com" --username="sample" --password="example value!$"')
        self.assertEqual(args.password, 'example value!$')

    def test_embedded_credentials_and_incomplete_pair_rejected(self):
        for raw in ('--portal_address=https://u:p@vpn.example.com',
                    '--portal_address=https://vpn.example.com --username=sample',
                    '--portal_address=file:///tmp/file',
                    '--portal_address=https://vpn.example.com --keepalive=-1'):
            with self.subTest(raw=raw), self.assertRaises(ValueError):
                helper.options(raw)

    def test_manual_mode_has_no_credentials(self):
        args = helper.options('--portal_address=https://vpn.example.com')
        self.assertIsNone(args.username)
        self.assertIsNone(args.password)

    @patch.object(helper.time, 'sleep')
    def test_failed_input_never_submits(self, sleep):
        driver = Mock()
        fields = [Mock(), Mock()]
        for field in fields:
            field.get_attribute.return_value = 'truncated'
        with patch.object(helper, 'visible_fields', return_value=fields):
            with self.assertRaises(helper.AuthenticationRejected):
                helper.submit_once(driver, 'sample', 'example-password')
        driver.find_elements.assert_not_called()

    def test_login_route_is_not_success(self):
        driver = Mock(current_url='https://vpn.example.com/portal/#/login')
        self.assertFalse(helper.logged_in(driver))

    def test_workspace_is_success(self):
        driver = Mock(current_url='https://vpn.example.com/portal/#/app_center')
        driver.find_element.return_value.text = 'Workspace'
        self.assertTrue(helper.logged_in(driver))

    def test_rejected_credentials_stop_before_another_attempt(self):
        driver = Mock()
        driver.find_element.return_value.text = '用户名或密码错误，您还有4次尝试的机会'
        args = helper.options('--portal_address=https://vpn.example.com --username=sample --password=example')
        with patch.object(helper, 'submit_once') as submit:
            with self.assertRaises(helper.AuthenticationRejected):
                helper.authenticate(driver, args)
            submit.assert_not_called()

    def test_session_revocation_is_not_success(self):
        driver = Mock()
        driver.find_element.return_value.text = '账号已注销：会话劫持'
        self.assertTrue(helper.rejection(driver))


if __name__ == '__main__':
    unittest.main()
