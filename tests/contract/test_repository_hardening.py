import unittest
from pathlib import Path

REPOSITORY_ROOT = Path(__file__).resolve().parents[2]


class RepositoryHardeningContractTest(unittest.TestCase):
    def test_required_hardening_artifacts_exist(self) -> None:
        expected_paths = (
            ".env.test.example",
            ".github/workflows/ci.yml",
            ".gitignore",
            "Makefile",
            "compose.test.yml",
            "pyproject.toml",
            "requirements-dev.txt",
            "tests/fixtures/golden/base.sql",
            "tests/fixtures/golden/allocation.sql",
            "tests/fixtures/golden/costs.sql",
            "tests/fixtures/golden/revenue.sql",
        )

        missing = [
            path for path in expected_paths if not (REPOSITORY_ROOT / path).is_file()
        ]

        self.assertEqual([], missing, f"missing hardening artifacts: {missing}")

    def test_readme_documents_the_v1_contract_and_local_workflow(self) -> None:
        readme = (REPOSITORY_ROOT / "README.md").read_text(encoding="utf-8")
        required_sections = (
            "## Deployable v1 contract",
            "## Architecture",
            "## Local development",
            "## Verification",
            "## Explicit exclusions",
        )

        for section in required_sections:
            with self.subTest(section=section):
                self.assertIn(section, readme)

    def test_migration_runner_targets_the_committed_schema_directory(self) -> None:
        runner = (REPOSITORY_ROOT / "migrations/bin/migrate.sh").read_text(
            encoding="utf-8"
        )

        self.assertIn('"$repository_root/schema"', runner)
        self.assertIn("-name '[0-9][0-9]_*.sql'", runner)
        self.assertNotIn("migrations/sql/000*.sql", runner)

    def test_ci_executes_the_database_tooling(self) -> None:
        workflow = (REPOSITORY_ROOT / ".github/workflows/ci.yml").read_text(
            encoding="utf-8"
        )

        self.assertIn("bash migrations/bin/migrate.sh", workflow)
        self.assertIn("bash migrations/bin/verify.sh", workflow)

    def test_publish_verification_requires_final_reconciliation(self) -> None:
        verifier = (REPOSITORY_ROOT / "migrations/bin/verify.sh").read_text(
            encoding="utf-8"
        )

        self.assertIn("reconciliation.stage = 'final_reconciliation'", verifier)
        self.assertIn("NOT EXISTS", verifier)


if __name__ == "__main__":
    unittest.main()
