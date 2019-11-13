#!/usr/bin/env bash

set -ueo pipefail

export HAB_ORIGIN='ci'
export PLAN='inspec'
export CHEF_LICENSE="accept-no-persist"
export HAB_LICENSE="accept-no-persist"
export HAB_BINLINK_DIR="/hab/bin"

echo "--- system details"
uname -a

echo "--- Generating fake origin key"
hab origin key generate $HAB_ORIGIN
HAB_CI_KEY=$(realpath "$HOME"/.hab/cache/keys/"$HAB_ORIGIN"*.pub)
export HAB_CI_KEY

echo "--- Building $PLAN"
project_root="$(git rev-parse --show-toplevel)"
cd "$project_root"

DO_CHECK=true hab pkg build .

echo "--- Sourcing 'results/last_build.sh'"
if [ -f ./results/last_build.env ]; then
    . ./results/last_build.env
    export pkg_artifact
    export project_root
fi

echo "+++ Installing ${pkg_ident:?is undefined}"

# habitat sudo install
HSI="$project_root"/.expeditor/buildkite/artifact.habitat.install.sh

sudo -E "$HSI"

echo "+++ Testing $PLAN"

PATH="${HAB_BINLINK_DIR:?is undefined}:$PATH"
export PATH
echo "PATH is $PATH"

pushd "$project_root/test/artifact"
hab pkg exec core/ruby rake
popd
