#!/bin/bash
# Copyright 2022 Google LLC.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


# Builds all python versions for release on Pypi
#
# CI: when true, skip TTY flags and bind-mount host cache directories.

set -vex

if [[ "$INTERACTIVE" = 1 ]]; then
  PYTHON_VERSIONS=( 3.12 )
else
  PYTHON_VERSIONS=( 3.9 3.10 3.11 3.12 3.13 3.14 )
fi

function build_py() {
  VERSION=$1
  COMPACT="${VERSION//./}"
  echo "Build YDF for python $VERSION"

  # manylinux images keep CPython under /opt/python/cpXY-cpXY, not on PATH.
  PY_CANDIDATE="/opt/python/cp${COMPACT}-cp${COMPACT}/bin/python"
  PY_RESOLVE="if [ -x ${PY_CANDIDATE} ]; then PY=${PY_CANDIDATE}; else PY=python${VERSION}; fi"

  if [[ "$INTERACTIVE" = 1 ]]; then
    CMD="${PY_RESOLVE}; \$PY -m venv /tmp/venv && source /tmp/venv/bin/activate && /bin/bash"
    echo "In the interactive shell, you can run commands such as:"
    echo "Run all the tests: RUN_TESTS=1 ./tools/build_test_linux.sh"
    echo "or"
    echo "Create a release: RUN_TESTS=0 ./tools/build_test_linux.sh && ./tools/package_linux.sh"
  else
    CMD="${PY_RESOLVE}; \$PY -m venv /tmp/venv && source /tmp/venv/bin/activate && RUN_TESTS=0 ./tools/build_test_linux.sh && ./tools/package_linux.sh"
  fi

  local docker_tty=()
  if [[ -t 1 && "${CI:-}" != "true" ]]; then
    docker_tty=(-it)
  fi

  local cache_mount="pydf_bazel_cache_${VERSION}:/root/.cache"
  local venv_mount="pydf_venv_cache_${VERSION}:/tmp/venv"
  if [[ "${CI:-}" == "true" ]]; then
    mkdir -p "${PWD}/../../../.ci-cache/bazel" "${PWD}/../../../.ci-cache/venv-${VERSION}"
    cache_mount="${PWD}/../../../.ci-cache/bazel:/root/.cache"
    venv_mount="${PWD}/../../../.ci-cache/venv-${VERSION}:/tmp/venv"
  fi

  docker run \
    -v "${venv_mount}" \
    -v "${cache_mount}" \
    -v "$(pwd)/../../../:/src" \
    -e CI \
    -e BAZEL_EXTRA_FLAGS \
    -w /src/yggdrasil_decision_forests/port/python \
    "${docker_tty[@]}" \
    --rm \
    build_pydf \
    "${CMD}"
}

function main() {
  docker build -t build_pydf .

  for VERSION in ${PYTHON_VERSIONS[*]} ; do
    build_py $VERSION
  done
}

main
