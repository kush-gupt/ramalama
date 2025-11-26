"""Squashfs conversion module for ramalama."""

import os
import tempfile

from ramalama.common import perror, run_cmd
from ramalama.engine import dry_run


def create_squashfs(source_model, target_path, args):
    """Create a squashfs image from a model inside a container for reproducibility."""
    if not args.container:
        raise ValueError("squashfs conversion requires a container engine")

    ref_file = source_model.model_store.get_ref_file(source_model.model_tag)
    if ref_file is None:
        raise ValueError(f"Model {source_model.model} not found in store")

    if not target_path.endswith(".squashfs"):
        target_path = f"{target_path}.squashfs"

    target_path = os.path.abspath(target_path)
    target_dir = os.path.dirname(target_path)
    target_filename = os.path.basename(target_path)
    os.makedirs(target_dir, exist_ok=True)

    perror(f"Converting {source_model.model} to squashfs...")

    with tempfile.TemporaryDirectory(prefix="ramalama_squashfs_") as staging_dir:
        models_dir = os.path.join(staging_dir, "models")
        model_subdir = os.path.join(models_dir, source_model.model_name)
        os.makedirs(model_subdir)

        # Create symlinks pointing to /blobs/<hash> (valid inside container)
        for file in ref_file.files:
            blob_name = os.path.basename(source_model.model_store.get_blob_file_path(file.hash))
            os.symlink(f"/blobs/{blob_name}", os.path.join(model_subdir, file.name))

        if ref_file.model_files:
            os.symlink(
                f"{source_model.model_name}/{ref_file.model_files[0].name}",
                os.path.join(models_dir, "model.file"),
            )

        blobs_dir = source_model.model_store.blobs_directory
        conman_args = [
            args.engine,
            "run",
            "--rm",
            "--security-opt=label=disable",
            "--cap-drop=all",
            "--security-opt=no-new-privileges",
            "--network=none",
            f"--pull={args.pull}",
            "-v",
            f"{staging_dir}:/input:ro",
            "-v",
            f"{blobs_dir}:/blobs:ro",
            "-v",
            f"{target_dir}:/output:rw",
            "--env",
            "SOURCE_DATE_EPOCH=0",
            args.image,
            "mksquashfs",
            "/input",
            f"/output/{target_filename}",
            "-comp",
            args.compression,
            "-no-xattrs",
            "-noappend",
            "-no-exports",
            "-no-progress",
        ]

        if args.dryrun:
            dry_run(conman_args)
        else:
            run_cmd(conman_args, stdout=None)
            perror(f"Created squashfs image: {target_path}")
