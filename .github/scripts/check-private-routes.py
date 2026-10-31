#!/usr/bin/env python3
"""Fail if any Traefik router for a private domain lacks the private-only middleware.

Traefik picks a router by the requested hostname, not by the address the
request arrived on. A private hostname (one whose DNS points at the tailnet)
is still reachable through the public IP unless its router also restricts
the client address. See traefik/dynamic/nas.yml for private-only.
"""
import glob
import re
import sys

import yaml

PRIVATE_DOMAINS = ("bit.vet",)
MIDDLEWARE = "private-only"


def is_private(rule: str) -> bool:
    hosts = re.findall(r"Host\(`([^`]+)`\)", rule)
    return any(h == d or h.endswith("." + d) for h in hosts for d in PRIVATE_DOMAINS)


def has_middleware(middlewares) -> bool:
    if isinstance(middlewares, str):
        middlewares = middlewares.split(",")
    return any(m.strip().split("@")[0] == MIDDLEWARE for m in middlewares or [])


problems = []

# Routers declared with Docker labels in compose files.
for path in sorted(glob.glob("*/compose.yml")):
    compose = yaml.safe_load(open(path)) or {}
    for service_name, service in (compose.get("services") or {}).items():
        labels = service.get("labels") or []
        if isinstance(labels, dict):
            labels = [f"{k}={v}" for k, v in labels.items()]
        routers = {}
        for label in labels:
            m = re.match(r"traefik\.http\.routers\.([^.]+)\.(rule|middlewares)=(.*)", str(label))
            if m:
                routers.setdefault(m.group(1), {})[m.group(2)] = m.group(3)
        for name, r in routers.items():
            if is_private(r.get("rule", "")) and not has_middleware(r.get("middlewares")):
                problems.append(f"{path}: router '{name}' ({r['rule']})")

# Routers declared in Traefik's file provider.
for path in sorted(glob.glob("traefik/dynamic/*.yml")):
    config = yaml.safe_load(open(path)) or {}
    for name, r in ((config.get("http") or {}).get("routers") or {}).items():
        if is_private(r.get("rule", "")) and not has_middleware(r.get("middlewares")):
            problems.append(f"{path}: router '{name}' ({r['rule']})")

if problems:
    print(f"These routers serve a private domain but don't use the {MIDDLEWARE} middleware,")
    print("so they're reachable from the internet through the public IP:\n")
    for p in problems:
        print(f"  {p}")
    print(f'\nAdd "traefik.http.routers.<name>.middlewares={MIDDLEWARE}@file" (or put it first in an existing list).')
    sys.exit(1)
print("All private routers use private-only.")
