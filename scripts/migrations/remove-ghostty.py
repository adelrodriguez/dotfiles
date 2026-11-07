#!/usr/bin/env python3
"""Retarget the link migration fixtures to the remaining bat configuration."""
from pathlib import Path

repo = Path(__file__).resolve().parents[2]
path = repo / 'tests/link.sh'
path.write_text(path.read_text().replace('ghostty', 'bat'))
