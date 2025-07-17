import json
import os
import pathlib
import urllib.request
import urllib.error

from ramalama.common import available, perror, run_cmd
from ramalama.hf_style_repo_base import (
    HFStyleRepoFile,
    HFStyleRepoModel,
    HFStyleRepository,
    fetch_checksum_from_api_base,
)
from ramalama.logger import logger
from ramalama.model_store.snapshot_file import SnapshotFile, SnapshotFileType

missing_huggingface = """
Optional: Huggingface models require the huggingface-cli module.
This module can be installed via PyPI tools like uv, pip, pip3, pipx, or via
distribution package managers like dnf or apt. Example:
uv pip install huggingface_hub
"""


def is_huggingface_cli_available():
    """Check if huggingface-cli is available on the system."""
    return available("huggingface-cli")


def huggingface_token():
    """Return cached Hugging Face token if it exists otherwise None"""
    token_path = os.path.expanduser(os.path.join("~", ".cache", "huggingface", "token"))
    if os.path.exists(token_path):
        try:
            with open(token_path) as tokenfile:
                return tokenfile.read().strip()
        except OSError:
            pass


def extract_huggingface_checksum(file_url):
    """Extract the SHA-256 checksum for the file at the URL."""
    import hashlib

    try:
        with urllib.request.urlopen(file_url) as response:
            file_content = response.read()
            # File is binary so calculating sha256 hash
            return hashlib.sha256(file_content).hexdigest()
    except Exception:
        return ""


def fetch_checksum_from_api(organization, file):
    """Fetch the SHA-256 checksum from the model's metadata API for a given file."""
    checksum_api_url = f"{HuggingfaceRepository.REGISTRY_URL}/{organization}/raw/main/{file}"
    headers = {}
    token = huggingface_token()
    if token is not None:
        headers['Authorization'] = f"Bearer {token}"

    return fetch_checksum_from_api_base(checksum_api_url, headers, extract_huggingface_checksum)


def fetch_repo_manifest(repo_name: str, tag: str = "latest"):
    # Replicate llama.cpp -hf logic
    # https://github.com/ggml-org/llama.cpp/blob/7f323a589f8684c0eb722e7309074cb5eac0c8b5/common/arg.cpp#L611
    token = huggingface_token()
    repo_manifest_url = f"{HuggingfaceRepository.REGISTRY_URL}/v2/{repo_name}/manifests/{tag}"
    logger.debug(f"Fetching repo manifest from {repo_manifest_url}")
    request = urllib.request.Request(
        url=repo_manifest_url,
        headers={
            'User-agent': 'llama-cpp',  # Note: required to return ggufFile field
            'Accept': 'application/json',
        },
    )
    if token is not None:
        request.add_header('Authorization', f"Bearer {token}")

    with urllib.request.urlopen(request) as response:
        repo_manifest = response.read().decode('utf-8')
        return json.loads(repo_manifest)


def get_repo_info(repo_name):
    # Docs on API call:
    # https://huggingface.co/docs/hub/en/api#get-apimodelsrepoid-or-apimodelsrepoidrevisionrevision
    repo_info_url = f"https://huggingface.co/api/models/{repo_name}"
    headers = {}
    token = huggingface_token()
    if token is not None:
        headers['Authorization'] = f"Bearer {token}"
    
    logger.debug(f"Fetching repo info from {repo_info_url}")
    request = urllib.request.Request(repo_info_url, headers=headers)
    with urllib.request.urlopen(request) as response:
        if response.getcode() == 200:
            repo_info = response.read().decode('utf-8')
            return json.loads(repo_info)
        else:
            perror("Huggingface repo information pull failed")
            raise KeyError(f"Response error code from repo info pull: {response.getcode()}")
    return None


class HuggingfaceRepository(HFStyleRepository):
    REGISTRY_URL = "https://huggingface.co"

    def __init__(self, name: str, organization: str, tag: str = 'latest'):
        self.use_full_repo = False
        self.files_info = []
        super().__init__(name, organization, tag)

    def fetch_metadata(self):
        # Repo org/name. Detect model type by checking repository files first
        self.blob_url = f"{HuggingfaceRepository.REGISTRY_URL}/{self.organization}/{self.name}/resolve/main"
        token = huggingface_token()
        if token is not None:
            self.headers['Authorization'] = f"Bearer {token}"
        
        # First, get repository info to detect model type
        repo_info = get_repo_info(f"{self.organization}/{self.name}")
        
        if 'siblings' not in repo_info:
            # Fallback if no file list available
            self.use_full_repo = True
            self.model_filename = "model.safetensors"
            self.model_hash = f"sha256:unknown"
            self.mmproj_filename = None
            self.mmproj_hash = None
            return
            
        self.files_info = repo_info['siblings']
        
        # Check what types of model files exist
        gguf_files = [f for f in self.files_info if f['rfilename'].endswith('.gguf')]
        safetensor_files = [f for f in self.files_info if f['rfilename'].endswith(('.safetensors', '.safetensor'))]
        
        if gguf_files:
            # GGUF repository - use manifest approach
            logger.debug(f"Detected GGUF repository for {self.organization}/{self.name}")
            self.use_full_repo = False
            
            try:
                self.manifest = fetch_repo_manifest(f"{self.organization}/{self.name}", self.tag)
                self.model_filename = self.manifest['ggufFile']['rfilename']
                self.model_hash = self.manifest['ggufFile']['blobId']
                self.mmproj_filename = self.manifest.get('mmprojFile', {}).get('rfilename', None)
                self.mmproj_hash = self.manifest.get('mmprojFile', {}).get('blobId', None)
            except (KeyError, urllib.error.HTTPError):
                # Fallback to using first GGUF file if manifest fails
                main_gguf = gguf_files[0]
                self.model_filename = main_gguf['rfilename']
                self.model_hash = main_gguf.get('oid', f"sha256:{main_gguf['rfilename']}")
                self.mmproj_filename = None
                self.mmproj_hash = None
                
        elif safetensor_files:
            # SafeTensor repository - use full repository API
            logger.debug(f"Detected SafeTensor repository for {self.organization}/{self.name}")
            self.use_full_repo = True
            
            # Use the first SafeTensor file as the "main" model file
            main_model = safetensor_files[0]
            self.model_filename = main_model['rfilename']
            
            # Use the repository's sha as a stable hash for the snapshot
            self.model_hash = f"sha256:{repo_info.get('sha', 'unknown')}"
            self.mmproj_filename = None
            self.mmproj_hash = None
            
        else:
            # No recognized model files - fallback to full repo approach
            logger.debug(f"No recognized model files found for {self.organization}/{self.name}, using full repository API")
            self.use_full_repo = True
            self.model_filename = "model.safetensors"
            self.model_hash = f"sha256:{repo_info.get('sha', 'unknown')}"
            self.mmproj_filename = None
            self.mmproj_hash = None

    def get_file_list(self, cached_files: list[str]) -> list[SnapshotFile]:
        if self.use_full_repo:
            # Return all relevant files for the model using full repository approach
            files = []
            
            for file_info in self.files_info:
                filename = file_info['rfilename']
                
                if filename in cached_files:
                    continue
                    
                # Determine file type
                file_type = SnapshotFileType.Other
                if filename.endswith(('.safetensors', '.safetensor')):
                    file_type = SnapshotFileType.Model
                elif filename.endswith('.gguf'):
                    file_type = SnapshotFileType.Model
                elif 'mmproj' in filename.lower():
                    file_type = SnapshotFileType.Mmproj
                    
                # Create file hash - use the file's oid if available, otherwise generate from filename
                file_hash = file_info.get('oid', f"sha256:{filename}")
                
                files.append(SnapshotFile(
                    url=f"{self.blob_url}/{filename}",
                    header=self.headers,
                    hash=file_hash,
                    type=file_type,
                    name=filename,
                    should_show_progress=file_type == SnapshotFileType.Model,
                    should_verify_checksum=False,  # Skip checksum verification for now
                    required=file_type == SnapshotFileType.Model,
                ))
            
            return files
        else:
            # Use the standard GGUF approach
            return super().get_file_list(cached_files)


class HuggingfaceRepositoryModel(HuggingfaceRepository):
    def fetch_metadata(self):
        # Model url. organization is <org>/<repo>, name is model file path
        self.blob_url = f"{HuggingfaceRepository.REGISTRY_URL}/{self.organization}/resolve/main"
        self.model_hash = f"sha256:{fetch_checksum_from_api(self.organization, self.name)}"
        self.model_filename = self.name
        token = huggingface_token()
        if token is not None:
            self.headers['Authorization'] = f"Bearer {token}"





class HuggingfaceCLIFile(HFStyleRepoFile):
    def __init__(
        self, url, header, hash, name, type, should_show_progress=False, should_verify_checksum=False, required=True
    ):
        super().__init__(url, header, hash, name, type, should_show_progress, should_verify_checksum, required)


class Huggingface(HFStyleRepoModel):
    REGISTRY_URL = "https://huggingface.co/v2/"
    ACCEPT = "Accept: application/vnd.docker.distribution.manifest.v2+json"

    def __init__(self, model, model_store_path):
        super().__init__(model, model_store_path)

        self.type = "huggingface"
        self.hf_cli_available = is_huggingface_cli_available()

    def get_cli_command(self):
        return "huggingface-cli"

    def get_missing_message(self):
        return missing_huggingface

    def get_registry_url(self):
        return self.REGISTRY_URL

    def get_accept_header(self):
        return self.ACCEPT

    def get_repo_type(self):
        return "huggingface"

    def fetch_checksum_from_api(self, organization, file):
        return fetch_checksum_from_api(organization, file)

    def create_repository(self, name, organization, tag):
        if '/' in organization:
            return HuggingfaceRepositoryModel(name, organization, tag)
        else:
            return HuggingfaceRepository(name, organization, tag)

    def get_cli_download_args(self, directory_path, model):
        return ["huggingface-cli", "download", "--local-dir", directory_path, model]

    def extract_model_identifiers(self):
        model_name, model_tag, model_organization = super().extract_model_identifiers()
        if '/' not in model_organization:
            # if it is a repo then normalize the case insensitive quantization tag
            if model_tag != "latest":
                model_tag = model_tag.upper()
        else:
            # Handle (org/repo/file.gguf)
            org_parts = model_organization.split('/')
            if len(org_parts) >= 2:
                if len(org_parts) > 2 or model_name.endswith(('.gguf', '.safetensors', '.safetensor')):
                    actual_organization = org_parts[0]
                    actual_name = org_parts[1] if len(org_parts) >= 2 else model_name
                    return actual_name, model_tag, actual_organization
        return model_name, model_tag, model_organization

    def _fetch_snapshot_path(self, cache_dir, namespace, repo):
        cache_path = os.path.join(cache_dir, f'models--{namespace}--{repo}')
        main_ref_path = os.path.join(cache_path, 'refs', 'main')
        if not (os.path.exists(cache_path) and os.path.exists(main_ref_path)):
            return None, None
        with open(main_ref_path, 'r') as file:
            snapshot = file.read().strip()
        snapshot_path = os.path.join(cache_path, 'snapshots', snapshot)
        return snapshot_path, cache_path

    def in_existing_cache(self, args, target_path, sha256_checksum):
        if not self.hf_cli_available:
            return False

        default_hf_caches = [os.path.join(os.path.expanduser('~'), '.cache/huggingface/hub')]
        namespace, repo = os.path.split(str(self.directory))

        for cache_dir in default_hf_caches:
            snapshot_path, cache_path = self._fetch_snapshot_path(cache_dir, namespace, repo)
            if not snapshot_path or not os.path.exists(snapshot_path):
                continue

            file_path = os.path.join(snapshot_path, self.filename)
            if not os.path.exists(file_path):
                continue

            blob_path = pathlib.Path(file_path).resolve()
            if not os.path.exists(blob_path):
                continue

            blob_file = os.path.relpath(blob_path, start=os.path.join(cache_path, 'blobs'))
            if str(blob_file) != str(sha256_checksum):
                continue

            os.symlink(blob_path, target_path)
            return True
        return False

    def push(self, _, args):
        if not self.hf_cli_available:
            raise NotImplementedError(self.get_missing_message())
        proc = run_cmd(
            [
                "huggingface-cli",
                "upload",
                "--repo-type",
                "model",
                self.directory,
                self.filename,
                "--cache-dir",
                os.path.join(args.store, "repos", "huggingface", ".cache"),
                "--local-dir",
                os.path.join(args.store, "repos", "huggingface", self.directory),
            ],
        )
        return proc.stdout.decode("utf-8")

    def _collect_cli_files(self, tempdir: str) -> tuple[str, list[HuggingfaceCLIFile]]:
        cache_dir = os.path.join(tempdir, ".cache", "huggingface", "download")
        files: list[HuggingfaceCLIFile] = []
        snapshot_hash = ""
        for entry in os.listdir(tempdir):
            entry_path = os.path.join(tempdir, entry)
            if os.path.isdir(entry_path) or entry == ".gitattributes":
                continue
            sha256 = ""
            metadata_path = os.path.join(cache_dir, f"{entry}.metadata")
            if not os.path.exists(metadata_path):
                continue
            with open(metadata_path) as metafile:
                lines = metafile.readlines()
                if len(lines) < 2:
                    continue
                sha256 = f"sha256:{lines[1].strip()}"
            if sha256 == "sha256:":
                continue
            if entry.lower() == "readme.md":
                snapshot_hash = sha256
                continue

            hf_file = HuggingfaceCLIFile(
                url=entry_path,
                header={},
                hash=sha256,
                type=SnapshotFileType.Other,
                name=entry,
            )
            # try to identify the model file in the pulled repo
            if entry.endswith(".gguf"):
                hf_file.type = SnapshotFileType.Model
            files.append(hf_file)

        return snapshot_hash, files
