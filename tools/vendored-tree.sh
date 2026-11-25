#!/bin/sh
# What configure and configure.win both require of the vendored tree.
# The list is tools/vendored-sentinels. A trailing slash is a directory.
#
#   sh tools/vendored-tree.sh
#       Print missing sentinels and exit 1, or exit 0 when every one is
#       present. Exit 2 when the list itself cannot be read.
#   sh tools/vendored-tree.sh --list
#       Print every sentinel, one per line.
#   sh tools/vendored-tree.sh --require-checksum LABEL
#       Exit 1 when the readcon crate checksum is absent. The tarball
#       stores that checksum under a name that is not hidden; either
#       name satisfies the check.

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
pkg=$(CDPATH='' cd -- "${script_dir}/.." && pwd)
list=${script_dir}/vendored-sentinels

die() {
  printf '%s\n' "vendored-tree.sh: $1" >&2
  exit 2
}

if [ ! -f "${list}" ]; then
  die "${list} is missing"
fi

# mode is "list" or "check". check prints each missing path and returns 1
# when any is missing. The last line of the list need not end in a newline.
read_sentinels() {
  mode=$1
  root=$2
  missing=0
  while IFS= read -r path || [ -n "${path}" ]; do
    path=$(printf '%s' "${path}" | tr -d '\r')
    case "${path}" in
      ""|\#*) continue ;;
    esac
    if [ "${mode}" = list ]; then
      printf '%s\n' "${path}"
      continue
    fi
    case "${path}" in
      */)
        if [ ! -d "${root}/${path}" ]; then
          printf '%s\n' "${path}"
          missing=1
        fi
        ;;
      *)
        if [ ! -f "${root}/${path}" ]; then
          printf '%s\n' "${path}"
          missing=1
        fi
        ;;
    esac
  done < "${list}"
  return "${missing}"
}

case "${1:-}" in
  --list)
    read_sentinels list "${pkg}"
    exit 0
    ;;
  --require-checksum)
    label=${2:-configure}
    sum=${pkg}/src/readcon-core/vendor/dlpk/cargo-checksum.json
    hidden=${pkg}/src/readcon-core/vendor/dlpk/.cargo-checksum.json
    if [ ! -f "${sum}" ] && [ ! -f "${hidden}" ]; then
      printf '%s\n' "${label}: src/readcon-core/vendor is missing; the source package has no vendored crates" >&2
      exit 1
    fi
    exit 0
    ;;
  "")
    read_sentinels check "${pkg}"
    status=$?
    exit "${status}"
    ;;
  *)
    die "unknown argument ${1}"
    ;;
esac
