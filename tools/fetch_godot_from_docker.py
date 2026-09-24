#!/usr/bin/env python3
"""Extract the official Godot Linux binary from the barichello/godot-ci Docker image.

Fallback for sandboxes where github.com release downloads are blocked but Docker Hub
is reachable. Streams each image layer (newest first) and pulls out only
usr/local/bin/godot, so nothing but the binary touches disk.

Usage: fetch_godot_from_docker.py <godot-version> <output-path>
"""
import json
import sys
import tarfile
import urllib.request

IMAGE = "barichello/godot-ci"
MEMBER = "usr/local/bin/godot"
ACCEPT = ", ".join([
    "application/vnd.docker.distribution.manifest.v2+json",
    "application/vnd.oci.image.manifest.v1+json",
])


def get(url: str, token: str, accept: str = "") -> urllib.request.addinfourl:
    req = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}"})
    if accept:
        req.add_header("Accept", accept)
    return urllib.request.urlopen(req, timeout=120)


def main() -> int:
    version, out_path = sys.argv[1], sys.argv[2]
    token_url = (
        "https://auth.docker.io/token?service=registry.docker.io"
        f"&scope=repository:{IMAGE}:pull"
    )
    token = json.load(urllib.request.urlopen(token_url, timeout=60))["token"]
    base = f"https://registry-1.docker.io/v2/{IMAGE}"
    manifest = json.load(get(f"{base}/manifests/{version}", token, ACCEPT))
    config = json.load(get(f"{base}/blobs/{manifest['config']['digest']}", token))

    # Map non-empty history entries to layers; the Godot download step is the one
    # whose command mentions the godot-builds release.
    steps = [h.get("created_by", "") for h in config["history"] if not h.get("empty_layer")]
    candidates = [i for i, s in enumerate(steps) if "godot-builds" in s or "Godot_v" in s]
    if not candidates:
        candidates = list(range(len(manifest["layers"])))
    for idx in candidates:
        layer = manifest["layers"][idx]
        print(f"[fetch] scanning layer {idx} ({layer['size'] // 1_000_000} MB)", flush=True)
        with get(f"{base}/blobs/{layer['digest']}", token) as resp:
            with tarfile.open(fileobj=resp, mode="r|gz") as tar:
                for member in tar:
                    if member.name.lstrip("./") == MEMBER and member.isfile():
                        src = tar.extractfile(member)
                        assert src is not None
                        with open(out_path, "wb") as dst:
                            while chunk := src.read(1 << 20):
                                dst.write(chunk)
                        print(f"[fetch] wrote {out_path}", flush=True)
                        return 0
    print("[fetch] godot binary not found in image", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
