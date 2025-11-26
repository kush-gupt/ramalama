"""Unit tests for squashfs conversion module."""

import os
import tempfile
from unittest.mock import MagicMock, patch

import pytest


class MockArgs:
    def __init__(
        self, container=True, compression="zstd", image="test:latest", engine="podman", pull="newer", dryrun=False
    ):
        self.container = container
        self.compression = compression
        self.image = image
        self.engine = engine
        self.pull = pull
        self.dryrun = dryrun


class MockRefFile:
    def __init__(self, files=None, model_files=None):
        self.files = files or []
        self.model_files = model_files or []


class MockModelStore:
    def __init__(self, blobs_dir):
        self.blobs_directory = blobs_dir
        self.ref_file = None

    def get_ref_file(self, model_tag):
        return self.ref_file

    def get_blob_file_path(self, file_hash):
        return os.path.join(self.blobs_directory, file_hash.replace(":", "-"))


class MockSourceModel:
    def __init__(self, model_store, model_name="test-model", model_tag="latest"):
        self.model_store = model_store
        self.model_name = model_name
        self.model_tag = model_tag
        self.model = f"{model_name}:{model_tag}"


class TestCreateSquashfs:
    def test_requires_container(self):
        from ramalama.squashfs import create_squashfs

        with pytest.raises(ValueError, match="requires a container engine"):
            create_squashfs(MagicMock(), "/tmp/out.squashfs", MockArgs(container=False))

    def test_raises_when_model_not_found(self):
        from ramalama.squashfs import create_squashfs

        with tempfile.TemporaryDirectory() as tmpdir:
            store = MockModelStore(tmpdir)
            store.ref_file = None
            with pytest.raises(ValueError, match="not found in store"):
                create_squashfs(MockSourceModel(store), "/tmp/out.squashfs", MockArgs())

    def test_appends_extension_and_creates_dir(self):
        from ramalama.squashfs import create_squashfs

        with tempfile.TemporaryDirectory() as tmpdir:
            store = MockModelStore(tmpdir)
            store.ref_file = MockRefFile()
            target_dir = os.path.join(tmpdir, "new_dir")

            with patch("ramalama.squashfs.dry_run") as mock:
                create_squashfs(MockSourceModel(store), os.path.join(target_dir, "out"), MockArgs(dryrun=True))
                assert os.path.isdir(target_dir)
                assert any("out.squashfs" in arg for arg in mock.call_args[0][0])

    def test_dryrun_does_not_run_cmd(self):
        from ramalama.squashfs import create_squashfs

        with tempfile.TemporaryDirectory() as tmpdir:
            store = MockModelStore(tmpdir)
            store.ref_file = MockRefFile()

            with patch("ramalama.squashfs.dry_run") as mock_dry, patch("ramalama.squashfs.run_cmd") as mock_run:
                create_squashfs(MockSourceModel(store), os.path.join(tmpdir, "out.squashfs"), MockArgs(dryrun=True))
                mock_dry.assert_called_once()
                mock_run.assert_not_called()

    @pytest.mark.parametrize("compression", ["gzip", "lz4", "zstd", "xz"])
    def test_compression_algorithms(self, compression):
        from ramalama.squashfs import create_squashfs

        with tempfile.TemporaryDirectory() as tmpdir:
            store = MockModelStore(tmpdir)
            store.ref_file = MockRefFile()

            with patch("ramalama.squashfs.dry_run") as mock:
                create_squashfs(
                    MockSourceModel(store),
                    os.path.join(tmpdir, "out.squashfs"),
                    MockArgs(dryrun=True, compression=compression),
                )
                args = mock.call_args[0][0]
                assert args[args.index("-comp") + 1] == compression

    def test_mounts_and_reproducibility(self):
        from ramalama.squashfs import create_squashfs

        with tempfile.TemporaryDirectory() as tmpdir:
            blobs_dir = os.path.join(tmpdir, "blobs")
            os.makedirs(blobs_dir)
            store = MockModelStore(blobs_dir)
            store.ref_file = MockRefFile()

            with patch("ramalama.squashfs.dry_run") as mock:
                create_squashfs(
                    MockSourceModel(store),
                    os.path.join(tmpdir, "out.squashfs"),
                    MockArgs(dryrun=True, image="custom:img"),
                )
                args = mock.call_args[0][0]
                assert any(f"{blobs_dir}:/blobs:ro" in a for a in args)
                assert "SOURCE_DATE_EPOCH=0" in args
                assert "custom:img" in args
                for flag in ["-no-xattrs", "-noappend", "-no-exports", "-no-progress"]:
                    assert flag in args
                # Verify mksquashfs only has /input as source
                mksquashfs_idx = args.index("mksquashfs")
                assert args[mksquashfs_idx + 1] == "/input"
                assert args[mksquashfs_idx + 2].startswith("/output/")
