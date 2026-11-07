#!/usr/bin/env python3
"""Invoke public service setup commands without installing or starting a service."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[2]


class Setup(unittest.TestCase):
    def test_setup_commands_reach_their_input_checks(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            (home / '.config/agents').mkdir(parents=True)
            (home / '.config/agents/runtime.path').write_text('/usr/bin\n/bin\n')
            env = {**os.environ, 'HOME': str(home), 'T3CODE_HOME': str(home / '.t3'),
                   'T3_BIN': str(home / 'missing-t3')}
            for command, message in [
                (['services/opencode/setup.sh', '--invalid'], 'Usage: services/opencode/setup.sh'),
                (['services/t3/setup.sh'], 'Install T3 Code first'),
            ]:
                with self.subTest(command=command):
                    process = subprocess.run([str(REPO / command[0]), *command[1:]], env=env,
                                             capture_output=True, text=True)
                    self.assertEqual(process.returncode, 1, process.stdout + process.stderr)
                    self.assertIn(message, process.stderr)


if __name__ == '__main__':
    unittest.main()
