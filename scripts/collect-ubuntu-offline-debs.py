#!/usr/bin/env python3
"""Tải toàn bộ .deb phụ thuộc của một gói local (máy build phải có mạng)."""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path


def run(cmd: list[str], check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(cmd, check=check, text=True, capture_output=True)


def parse_depends(field: str) -> list[str]:
    names: list[str] = []
    for part in field.split(","):
        part = part.strip()
        if not part:
            continue
        chosen = ""
        for alt in part.split("|"):
            name = re.split(r"[\s(]", alt.strip(), maxsplit=1)[0]
            if not name:
                continue
            shown = run(["apt-cache", "show", name], check=False)
            if shown.returncode == 0 and shown.stdout.strip():
                chosen = name
                break
        if chosen:
            names.append(chosen)
    return names


def recursive_packages(seeds: list[str]) -> list[str]:
    cmd = [
        "apt-cache",
        "depends",
        "--recurse",
        "--no-recommends",
        "--no-suggests",
        "--no-conflicts",
        "--no-breaks",
        "--no-replaces",
        "--no-enhances",
        *seeds,
    ]
    out = run(cmd).stdout
    names = set(seeds)
    for raw in out.splitlines():
        line = raw.strip()
        if not line or "<" in line or line.startswith("|"):
            continue
        if line.startswith("Depends:") or line.startswith("PreDepends:"):
            name = line.split()[-1]
            if re.fullmatch(r"[a-z0-9][a-z0-9+.-]+", name):
                names.add(name)
        elif ":" not in line and re.fullmatch(r"[a-z0-9][a-z0-9+.-]+", line):
            names.add(line)
    return sorted(names)


def download(packages: list[str], dest: Path) -> None:
    dest.mkdir(parents=True, exist_ok=True)
    failed: list[str] = []
    for pkg in packages:
        print(f"  download {pkg}", flush=True)
        result = subprocess.run(
            ["apt-get", "download", pkg],
            cwd=dest,
            text=True,
            capture_output=True,
        )
        if result.returncode != 0:
            failed.append(pkg)
            sys.stderr.write(result.stderr)
    if failed:
        sys.stderr.write("Không tải được (bỏ qua gói ảo/cung cấp bởi gói khác): "
                         + ", ".join(failed) + "\n")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("deb", type=Path)
    parser.add_argument("repo", type=Path)
    parser.add_argument("--extra", action="append", default=[])
    args = parser.parse_args()

    control = run(["dpkg-deb", "-f", str(args.deb), "Depends"]).stdout
    seeds = parse_depends(control)
    for extra in args.extra:
        if extra and extra not in seeds:
            seeds.append(extra)
    print("==> Gói gốc:", ", ".join(seeds), flush=True)
    packages = recursive_packages(seeds)
    print(f"==> {len(packages)} gói cần tải", flush=True)
    download(packages, args.repo)
    dest_deb = args.repo / args.deb.name
    dest_deb.write_bytes(args.deb.read_bytes())
    print("==> Đã chép", dest_deb.name, flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
