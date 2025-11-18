import os
import pathlib
from typing import List, Optional

# Constants for environment variables and paths
ENV_HF_TOKEN = "HF_TOKEN"
ENV_HF_HOME = "HF_HOME"
ENV_HF_HUB_CACHE = "HUGGINGFACE_HUB_CACHE"
DEFAULT_CACHE_HOME = os.path.expanduser("~/.cache/huggingface")


def _read_token_from_path(path: str) -> Optional[str]:
    try:
        with open(path) as f:
            return f.read().strip()
    except OSError:
        return None


def huggingface_token() -> Optional[str]:
    """Return cached Hugging Face token if it exists otherwise None"""
    if token := os.environ.get(ENV_HF_TOKEN):
        return token

    possible_paths = []
    if hf_home := os.environ.get(ENV_HF_HOME):
        possible_paths.append(os.path.join(hf_home, "token"))
    possible_paths.append(os.path.join(DEFAULT_CACHE_HOME, "token"))

    for path in possible_paths:
        if os.path.exists(path):
            if token := _read_token_from_path(path):
                return token
    return None


def get_hf_cache_dirs() -> List[str]:
    """Return a list of potential Hugging Face cache directories"""
    cache_dirs = []
    if hub_cache := os.environ.get(ENV_HF_HUB_CACHE):
        cache_dirs.append(hub_cache)
    if hf_home := os.environ.get(ENV_HF_HOME):
        cache_dirs.append(os.path.join(hf_home, "hub"))
    cache_dirs.append(os.path.join(DEFAULT_CACHE_HOME, "hub"))
    return cache_dirs


def _get_snapshot_path(cache_dir: str, namespace: str, repo: str) -> Optional[str]:
    cache_path = os.path.join(cache_dir, f'models--{namespace}--{repo}')
    ref_path = os.path.join(cache_path, 'refs', 'main')

    if not os.path.exists(ref_path):
        return None

    try:
        with open(ref_path, 'r') as f:
            snapshot = f.read().strip()
        return os.path.join(cache_path, 'snapshots', snapshot)
    except OSError:
        return None


def find_file_in_cache(directory: str, filename: str, sha256_checksum: str) -> Optional[str]:
    """Find a file in the Hugging Face cache matching the checksum."""
    namespace, repo = os.path.split(str(directory))
    expected_hash = sha256_checksum.removeprefix("sha256:")

    for cache_dir in get_hf_cache_dirs():
        snapshot_path = _get_snapshot_path(cache_dir, namespace, repo)
        if not snapshot_path:
            continue

        file_path = os.path.join(snapshot_path, filename)
        blob_path = pathlib.Path(file_path).resolve()

        if not blob_path.exists():
            continue

        # Verify it points to the correct blob in the cache
        if blob_path.name == expected_hash:
            return str(blob_path)

    return None


class CachedModelFile:
    def __init__(self, name: str, modified: float, size: int):
        self.name = name
        self.modified = modified
        self.size = size
        self.is_partial = False


def list_hf_cache_models() -> dict[str, List[CachedModelFile]]:
    """List models present in the HuggingFace cache directories"""
    models = {}

    for cache_dir in get_hf_cache_dirs():
        if not os.path.exists(cache_dir):
            continue

        try:
            entries = [e for e in os.listdir(cache_dir) if e.startswith("models--")]
        except OSError:
            continue

        for entry in entries:
            parts = entry.split("--")
            if len(parts) < 3:
                continue

            namespace, repo = parts[1], "--".join(parts[2:])
            snapshot_path = _get_snapshot_path(cache_dir, namespace, repo)

            if not snapshot_path:
                continue

            model_files = []
            for root, _, files in os.walk(snapshot_path):
                for file in files:
                    if file.endswith((".gguf", ".safetensors")):
                        try:
                            stat = os.stat(os.path.join(root, file))
                            model_files.append(CachedModelFile(file, stat.st_mtime, stat.st_size))
                        except OSError:
                            pass

            if model_files:
                key = f"hf://{namespace}/{repo}"
                models.setdefault(key, []).extend(model_files)

    return models
