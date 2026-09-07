"""Shared pytest fixtures.

Ensures the backend ``app`` package is importable from the tests and the
application factory is available to all test modules.
"""

from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))