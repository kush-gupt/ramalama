#! /bin/bash
if [[ "$#" != 2 ]]; then
    echo "Usage: $0 CURVERSION NEWVERSION"
    exit 1
fi
curversion=$1
newversion=$2
sed "s/${curversion}/${newversion}/g" -i pyproject.toml setup.py ramalama/version.py rpm/python-ramalama.spec scripts/release.sh scripts/release-image.sh
