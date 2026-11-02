#!/usr/bin/env python3
"""Create a Penpot profile through the backend prepl.

Usage:
    scripts/native/create-profile.py <email> [password] [fullname]

Defaults: password 123123, fullname "Test User". The backend must be running
(`just up`); it listens for prepl connections on 127.0.0.1:6063.
"""

import json
import os
import socket
import sys

HOST = os.environ.get("PENPOT_PREPL_HOST", "127.0.0.1")
PORT = int(os.environ.get("PENPOT_PREPL_PORT", "6063"))


def send(payload):
    with socket.create_connection((HOST, PORT), timeout=10) as sock:
        stream = sock.makefile(mode="rw")
        json.dump(payload, stream)
        stream.write("\n")
        stream.flush()
        while True:
            line = stream.readline()
            if not line:
                raise RuntimeError("prepl closed the connection")
            result = json.loads(line)
            if result.get("tag") == "ret":
                return result.get("val"), result.get("err")
            if result.get("tag") == "out":
                print(result.get("val"), end="")


def main():
    if len(sys.argv) < 2:
        print(__doc__.strip(), file=sys.stderr)
        return 2

    email = sys.argv[1]
    password = sys.argv[2] if len(sys.argv) > 2 else "123123"
    fullname = sys.argv[3] if len(sys.argv) > 3 else "Test User"

    payload = {
        "cmd": "create-profile",
        "params": {
            "fullname": fullname,
            "email": email,
            "password": password,
            "viewed-tutorial?": True,
            "viewed-walkthrough?": True,
        },
    }
    try:
        val, err = send(payload)
    except OSError as cause:
        print(f"error: cannot reach the backend prepl on {HOST}:{PORT} "
              f"({cause}); is the backend running?", file=sys.stderr)
        return 1

    if err:
        print(f"error: {err.get('hint', err)}", file=sys.stderr)
        return 1
    print(f"created {val.get('email')} / {val.get('id')}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
