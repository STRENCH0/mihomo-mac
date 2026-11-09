import base64
import json
from pathlib import Path, PurePosixPath
import re
import shutil
import subprocess
import sys
import time
from urllib.parse import urlparse


def github_json(endpoint):
    for attempt in range(3):
        result = subprocess.run(
            ["gh", "api", endpoint], capture_output=True, text=True, timeout=60
        )
        if result.returncode == 0:
            return json.loads(result.stdout)
        if attempt < 2:
            time.sleep(attempt + 1)
    raise RuntimeError(f"GitHub API request failed: {endpoint}\n{result.stderr.strip()}")


def collect_licenses(lockfile, destination):
    destination.mkdir(parents=True, exist_ok=True)
    for filename in ("LICENSE", "THIRD_PARTY_NOTICES.md"):
        shutil.copyfile(filename, destination / filename)

    pins = json.loads(lockfile.read_text())["pins"]
    manifest = []
    for pin in pins:
        identity = pin["identity"]
        location = pin["location"]
        revision = pin["state"]["revision"]
        parsed = urlparse(location)
        repository = parsed.path.removesuffix(".git").strip("/")
        if parsed.scheme != "https" or parsed.netloc != "github.com" or len(repository.split("/")) != 2:
            raise ValueError(f"Unsupported dependency repository: {location}")
        if not re.fullmatch(r"[a-zA-Z0-9_.-]+", identity) or not re.fullmatch(r"[0-9a-f]{40}", revision):
            raise ValueError(f"Invalid dependency pin: {identity}")

        tree = github_json(f"repos/{repository}/git/trees/{revision}?recursive=1")
        if tree.get("truncated"):
            raise ValueError(f"Incomplete repository tree: {identity}")
        entries = [
            entry for entry in tree["tree"]
            if entry["type"] == "blob" and re.match(
                r"^(licen[cs]e|copying|copyright|notice)([._-].*)?$",
                PurePosixPath(entry["path"]).name,
                re.IGNORECASE,
            )
        ]
        if not entries:
            entries = [entry for entry in tree["tree"] if entry["type"] == "blob" and entry["path"].lower() == "readme.md"]
        if not entries:
            raise ValueError(f"No license or attribution file found for dependency: {identity}")
        notices = []
        for entry in entries:
            path = PurePosixPath(entry["path"])
            if path.is_absolute() or ".." in path.parts:
                raise ValueError(f"Invalid license path: {path}")
            blob = github_json(f"repos/{repository}/git/blobs/{entry['sha']}")
            if blob["encoding"] != "base64":
                raise ValueError(f"Unsupported license encoding: {identity}/{path}")
            target = destination / identity / str(path)
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(base64.b64decode(blob["content"]))
            notices.append(str(path))
        manifest.append({"identity": identity, "location": location, "revision": revision, "notices": notices})
        print(f"Included {len(notices)} license or attribution files for {identity}", flush=True)

    (destination / "dependencies.json").write_text(json.dumps(manifest, indent=2) + "\n")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit("Usage: collect-licenses.py Package.resolved output-directory")
    collect_licenses(Path(sys.argv[1]), Path(sys.argv[2]))
