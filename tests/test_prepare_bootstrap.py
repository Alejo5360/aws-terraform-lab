"""Exercise external-path and overwrite guards without AWS or real Terraform state."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


REPOSITORY = Path(__file__).resolve().parents[1]
SCRIPT = REPOSITORY / "scripts" / "prepare-bootstrap.ps1"
POWERSHELL = os.environ.get("BOOTSTRAP_POWERSHELL") or shutil.which("pwsh") or shutil.which("powershell")


@unittest.skipUnless(POWERSHELL, "PowerShell is required to test the preparation helper")
class PrepareBootstrapTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="aws-terraform-bootstrap-tests-")
        self.root = Path(self.temp.name).resolve()
        self.state_dir = self.root / "private-state"

    def tearDown(self):
        # Only remove the generated test directory under the system temp root.
        if self.root.parent != Path(tempfile.gettempdir()).resolve() or not self.root.name.startswith("aws-terraform-bootstrap-tests-"):
            raise RuntimeError("Unsafe test cleanup path")
        self.temp.cleanup()

    def run_helper(self, directory=None, project="123456789012"):
        env = dict(os.environ)
        env.update({
            "BOOTSTRAP_TEST_SCRIPT": str(SCRIPT),
            "BOOTSTRAP_TEST_DIRECTORY": str(directory if directory is not None else self.state_dir),
            "BOOTSTRAP_TEST_PROJECT": project,
        })
        code = (
            "$ErrorActionPreference='Stop'; "
            "$result = & $env:BOOTSTRAP_TEST_SCRIPT -ExpectedAccountId $env:BOOTSTRAP_TEST_PROJECT "
            "-StateDirectory $env:BOOTSTRAP_TEST_DIRECTORY; "
            "$result | ConvertTo-Json -Compress"
        )
        return subprocess.run([POWERSHELL, "-NoProfile", "-NonInteractive", "-Command", code],
                              env=env, capture_output=True, text=True, encoding="utf-8", timeout=30)

    def test_generates_external_config_without_state_or_plan(self):
        result = self.run_helper()
        self.assertEqual(result.returncode, 0, result.stderr)
        paths = json.loads(result.stdout)
        backend = json.loads(Path(paths["BackendConfig"]).read_text(encoding="utf-8"))
        inputs = json.loads(Path(paths["VariablesFile"]).read_text(encoding="utf-8"))
        self.assertEqual(Path(backend["path"]).resolve(), self.state_dir / "terraform.tfstate")
        self.assertEqual(Path(backend["workspace_dir"]).resolve(), self.state_dir / "workspaces")
        self.assertEqual(inputs, {"expected_account_id": "123456789012", "aws_region": "us-east-2", "aws_profile": "devops-free"})
        for key in ["StateFile", "PlanFile"]:
            self.assertFalse(Path(paths[key]).exists())
            self.assertFalse(Path(paths[key]).resolve().is_relative_to(REPOSITORY))
        self.assertFalse(Path(paths["BackendConfig"]).read_bytes().startswith(b"\xef\xbb\xbf"))

    def test_identical_configuration_is_idempotent(self):
        first = self.run_helper()
        self.assertEqual(first.returncode, 0, first.stderr)
        path = Path(json.loads(first.stdout)["VariablesFile"])
        original = (path.read_bytes(), path.stat().st_mtime_ns)
        again = self.run_helper()
        self.assertEqual(again.returncode, 0, again.stderr)
        self.assertEqual((path.read_bytes(), path.stat().st_mtime_ns), original)

    def test_rejects_checkout_and_nested_paths(self):
        for directory in [REPOSITORY, REPOSITORY / "must-not-create-bootstrap-state"]:
            with self.subTest(directory=directory):
                result = self.run_helper(directory=directory)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("outside the repository", result.stderr)
        self.assertFalse((REPOSITORY / "must-not-create-bootstrap-state").exists())

    def test_rejects_relative_directory(self):
        result = self.run_helper(directory="relative-bootstrap-state")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("absolute path", result.stderr)

    def test_different_project_cannot_overwrite_existing_inputs(self):
        first = self.run_helper()
        self.assertEqual(first.returncode, 0, first.stderr)
        path = Path(json.loads(first.stdout)["VariablesFile"])
        original = path.read_bytes()
        other = self.run_helper(project="999999999999")
        self.assertNotEqual(other.returncode, 0)
        self.assertIn("configuration differs", other.stderr)
        self.assertEqual(path.read_bytes(), original)

    def test_invalid_project_creates_no_directory(self):
        result = self.run_helper(project="invalid")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.state_dir.exists())

    def test_rejects_existing_file_as_directory(self):
        existing = self.root / "existing-file"
        existing.write_text("keep", encoding="utf-8")
        result = self.run_helper(directory=existing)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(existing.read_text(encoding="utf-8"), "keep")

    def test_rejects_file_at_terraform_data_directory(self):
        self.state_dir.mkdir()
        collision = self.state_dir / "terraform-data"
        collision.write_text("keep", encoding="utf-8")
        result = self.run_helper()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("must be directories", result.stderr)
        self.assertEqual(collision.read_text(encoding="utf-8"), "keep")
        self.assertFalse((self.state_dir / "bootstrap.inputs.tfvars.json").exists())


if __name__ == "__main__":
    unittest.main()
