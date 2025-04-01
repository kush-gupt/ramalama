#!/bin/bash

available() {
  command -v "$1" >/dev/null
}

dnf_remove() {
  dnf remove -y \
      python3-devel \
      python3-pip \
      git 
  dnf -y clean all
}

dnf_install() {
  local rpm_list=("podman-remote" "python3" "python3-pip" \
		  "python3-argcomplete" "python3-devel" "git" \
		  "vim" "procps-ng" \
                  )
  dnf install -y "${rpm_list[@]}"
  dnf -y clean all
}

clone_and_build_ramalama() {
  # link podman-remote to podman for use by RamaLama
  ln -sf /usr/bin/podman-remote /usr/bin/podman
  git clone https://github.com/containers/ramalama
  cd ramalama
  git submodule update --init --recursive
  python3 -m pip install .
  cd ..
  rm -rf ramalama
}

main() {
  # shellcheck disable=SC1091
  source /etc/os-release

  set -ex
  dnf_install
  clone_and_build_ramalama
  dnf_remove
  rm -rf /var/cache/*dnf* /opt/rocm-*/lib/*/library/*gfx9*
}

main "$@"
