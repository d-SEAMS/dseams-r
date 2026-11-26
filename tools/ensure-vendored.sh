#!/bin/sh
# Vendor any sentinel missing from tools/vendored-sentinels.
# configure and configure.win both run this, so the decision cannot drift.
#
#   sh tools/ensure-vendored.sh LABEL
#
# LABEL is the calling script name and prefixes every message. A complete
# tree exits 0 without calling tools/vendor.sh. An incomplete tree calls
# it, then checks the sentinels again. vendor.sh can exit 0 without
# restoring a file (a stub, or a download that was refused). Configuring
# on from there writes src/Makevars for a package that cannot build, so
# a sentinel that is still missing is an error. A missing list, or a
# checker that fails without naming a path, is an error and does not
# vendor.

label=${1:-configure}
if [ ! -f tools/vendored-tree.sh ]; then
  printf '%s\n' "${label}: tools/vendored-tree.sh is missing" >&2
  exit 1
fi
missing=$(sh tools/vendored-tree.sh)
status=$?
if [ "${status}" -eq 0 ]; then
  exit 0
fi
if [ -z "${missing}" ]; then
  printf '%s\n' "${label}: could not check the vendored tree" >&2
  exit 1
fi
printf '%s\n' "${label}: the vendored tree is incomplete:" >&2
printf '%s\n' "${missing}" >&2
if [ ! -f tools/vendor.sh ]; then
  printf '%s\n' "${label}: engine sources are missing and there is no tools/vendor.sh to make them" >&2
  exit 1
fi
R_HOME=${R_HOME:-} sh tools/vendor.sh || exit 1
missing=$(sh tools/vendored-tree.sh)
status=$?
if [ "${status}" -eq 0 ]; then
  exit 0
fi
if [ -z "${missing}" ]; then
  printf '%s\n' "${label}: could not check the vendored tree after tools/vendor.sh" >&2
  exit 1
fi
printf '%s\n' "${label}: the vendored tree is still incomplete after tools/vendor.sh:" >&2
printf '%s\n' "${missing}" >&2
printf '%s\n' "${label}: refusing to configure a package with a missing vendored file" >&2
exit 1
