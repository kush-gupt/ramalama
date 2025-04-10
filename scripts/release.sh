#!/usr/bin/bash -ex

if [ -z "$1" ]; then
    echo "Usage: $0 IMAGE" >&2
    exit 1
fi

# Prior to running this script, I run
#    make build IMAGE=$IMAGE
#         Where image is one of: ramalama, asahi, cann and cuda on both X86 and ARM platforms.
#    Then on ARM Platform I first run release-image.sh $IMAGE to push the image
#    to the ARMREPO
# Once that is complete I run this script for each one of the $IMAGEs

# This script assumes that ARM images have been pushed to ARMREPO from
# MACS
export ARMREPO=${ARMREPO:"quay.io/rhatdan"}
export REPO=${REPO:"quay.io/ramalama"}

release() {
    DEST=${REPO}/"$1"
    podman manifest rm "$1" 2>/dev/null|| true
    podman manifest create "$1"
    id=$(podman image inspect "${DEST}" --format '{{ .Id }}')
    podman manifest add "$1" "$id"
    id=$(podman pull -q --arch arm64 "${ARMREPO}"/"$1")
    podman manifest add "$1" "$id"
    podman manifest inspect "$1"
    podman manifest push --all "$1" "${DEST}":0.7.3
    podman manifest push --all "$1" "${DEST}":0.7
    podman manifest push --all "$1" "${DEST}"
    podman manifest rm "$1"
}

case ${1} in
    ramalama-cli)
	podman run --rm "${REPO}"/"$1" /usr/bin/ramalama version
	release "$1"
	;;
    llama-stack)
	podman run --rm "${REPO}"/"$1" /usr/bin/llama
	release "$1"
	;;
    *)
	podman run --rm "${REPO}"/"$1" ls -l /usr/bin/llama-server
	podman run --rm "${REPO}"/"$1" ls -l /usr/bin/llama-run
	podman run --rm "${REPO}"/"$1" ls -l /usr/bin/whisper-server
	podman run --rm "${REPO}"/"$1"-rag rag_framework load

	release "$1"
	release "$1"-whisper-server
	release "$1"-llama-server
	release "$1"-rag
	;;
esac
