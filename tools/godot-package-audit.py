#!/usr/bin/env python3
"""Fail-closed audit for the asset-free Godot transfer package."""

from __future__ import annotations

import argparse
import hashlib
import pathlib
import subprocess
import sys


FORBIDDEN_SUFFIXES = {
    ".dff", ".txd", ".col", ".img", ".scm", ".gxt", ".ide", ".ipl",
    ".mpg", ".exe", ".dll", ".asi", ".sav",
}
FORBIDDEN_LINK_TEXT = ("wine", "/workspace", "/opt/conan", ".conan")
REQUIRED = {
    "runtime/godot",
    "godot/project.godot",
    "godot/sa_legacy.gdextension",
    "godot/bin/libsa_legacy.so",
    "licenses/GODOT_LICENSE.txt",
    "licenses/GODOT_CPP_LICENSE.md",
    "licenses/LIBRW_LICENSE.txt",
    "README.md",
    "DEPENDENCIES.md",
}


def fail(message: str) -> None:
    raise RuntimeError(message)


def command(*args: str) -> str:
    result = subprocess.run(args, check=True, text=True, capture_output=True)
    return result.stdout + result.stderr


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("package", type=pathlib.Path)
    args = parser.parse_args()
    root = args.package.resolve()
    if not root.is_dir():
        fail(f"package is not a directory: {root}")
    files: list[pathlib.Path] = []
    for path in root.rglob("*"):
        if path.is_symlink():
            fail(f"package symlink is forbidden: {path.relative_to(root)}")
        if path.is_file():
            files.append(path)
    relative = {str(path.relative_to(root)) for path in files}
    missing = sorted(REQUIRED - relative)
    if missing:
        fail(f"missing required files: {missing}")
    forbidden = sorted(name for name in relative if pathlib.Path(name).suffix.lower() in FORBIDDEN_SUFFIXES)
    if forbidden:
        fail(f"game/runtime-proprietary assets found: {forbidden}")
    extension = root / "godot/bin/libsa_legacy.so"
    runtime = root / "runtime/godot"
    for binary in (extension, runtime):
        identity = command("file", str(binary))
        if "ELF 64-bit" not in identity or "x86-64" not in identity:
            fail(f"not ELF64 x86-64: {binary}")
        links = command("ldd", str(binary))
        lower = links.lower()
        if "not found" in lower or any(token in lower for token in FORBIDDEN_LINK_TEXT):
            fail(f"invalid runtime dependency boundary: {binary}\n{links}")
    exports = command("nm", "--dynamic", "--defined-only", "--format=just-symbols", str(extension)).strip()
    if exports != "sa_legacy_library_init":
        fail(f"unexpected extension exports: {exports}")
    descriptor = (root / "godot/sa_legacy.gdextension").read_text(encoding="utf-8")
    if any(token in descriptor for token in ("/workspace", "/opt/conan", ".conan")):
        fail("descriptor contains build-tree path")
    digest = hashlib.sha256(extension.read_bytes()).hexdigest()
    version = command(str(runtime), "--version").splitlines()[0]
    print(
        "godot-package-audit-ok "
        f"files={len(files)} assets=0 symlinks=0 extension={digest} runtime={version} "
        "exe=0 wine=0 licenses=godot,godot-cpp,librw external-game-dir=required"
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (RuntimeError, subprocess.CalledProcessError, OSError) as error:
        print(f"godot-package-audit-fail: {error}", file=sys.stderr)
        raise SystemExit(1)
