#!/usr/bin/env bash

function join_by() {
  local d="$1"
  echo -n "$2"
  shift 2 && printf '%s' "${@/#/$d}"
}

for cmd in docker mktemp; do
  if ! type "$cmd" &>/dev/null; then
    echo "Missing command: $cmd"
    exit 1
  fi
done

SCRIPT_FILE="$(basename ${BASH_SOURCE[0]})"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

function exit_with_help() {
  >&2 echo "Usage: $SCRIPT_FILE [-v|--verbose] [--build-seed <file>] [--openwrt-version <refspec>] [-j <jobs>] [--make-args <args>] [--repo-url <url>] <refspec>"
  exit 1
}

args=(
  "v,verbose"
  ",openwrt-version:"
  "j:,"
  ",make-args:"
  ",repo-url:"
  ",build-seed:"
)

short_args=()
long_args=()
for arg in "${args[@]}"; do
  IFS=',' read -ra arg_arr <<< "$arg"
  short_args+=("${arg_arr[0]}")
  long_args+=("${arg_arr[1]}")
done

short_args="$(join_by ',' ${short_args[@]})"
long_args="$(join_by ',' ${long_args[@]})"

options="$(getopt -n "$SCRIPT_FILE" \
  -o="$short_args" \
  --long="$long_args" -- "$@" \
)" || exit_with_help

opt_openwrt_refspec="openwrt-22.03"
opt_repo_url="https://github.com/berlin-open-wireless-lab/dawn.git"
opt_build_seed="config.buildinfo"

eval set -- "$options"
while true; do
  # Check if "$1" is set
  [[ "${1:+1}" -ne 1 ]] && break

  # Parameter list ends with "--"
  [[ "$1" == "--" ]] && { shift; break; }

  case "$1" in
    -v|--verbose) opt_verbose=1 ;;
    -j) opt_jobcount="$2"; shift ;;
    --make-args) opt_make_args="$2"; shift ;;
    --repo-url) opt_repo_url="$2"; shift ;;
    --build-seed) opt_build_seed="$2"; shift ;;
    --openwrt-version) opt_openwrt_refspec="$2"; shift ;;
    *) >&2 echo "Unknown arg: $1"; exit_with_help ;;
  esac
  shift
done

if [[ "${1:+1}" -eq 1 ]]; then
  refspec="$1"
  shift
fi

# Check if we have too many parameters
[[ "${1:+1}" -eq 1 ]] && exit_with_help

# Make sure we have a refspec at this point
[[ -z "$refspec" ]] && exit_with_help

if [[ ! -f "$opt_build_seed" ]]; then
  >&2 echo "Build seed not found: $opt_build_seed"
  exit 1
fi

make_args=()
if [[ -n "$opt_verbose" ]]; then
  make_args+=("V=s")
fi

if [[ -n "$opt_jobcount" ]]; then
  make_args+=("-j$opt_jobcount")
fi

if [[ -n "$opt_make_args" ]]; then
  make_args+=("$opt_make_args")
fi

openwrt_builder_args=()
if [[ -n "$opt_verbose" ]]; then
  openwrt_builder_args+=("-v")
fi
openwrt_builder_args+=("$opt_openwrt_refspec")

# Convert make_args array into a string
make_args="$(join_by ' ' ${make_args[@]})"

echo "Building OpenWRT builder image for $opt_openwrt_refspec"
image_id="$("$DIR/openwrt-builder/build.sh" "${openwrt_builder_args[@]}")"
[[ "$?" -ne 0 ]] && exit 1

echo "Building DAWN"
if [[ -n "$opt_verbose" ]]; then
  echo "  repo-url: $opt_repo_url"
  echo "  make args: $make_args"
fi

iidfile="$(mktemp)"
function cleanup() { rm -rf "$iidfile"; }
trap cleanup EXIT

docker build "$DIR" \
  --build-arg CONFIG_PATH="$opt_build_seed" \
  --build-arg REPO_URL="$opt_repo_url" \
  --build-arg BASE_IMAGE="$image_id" \
  --build-arg MAKE_ARGS="$make_args" \
  --progress plain \
  --iidfile "$iidfile" || exit 1

if [[ ! -f "$iidfile" ]]; then
  echo "Missing iidfile"
  exit 1
fi

image_id="$(cat "$iidfile")"
rm "$iidfile"

echo "Finished building DAWN"
container_id="$(docker create "$image_id")"
rm -rf "build"
docker cp "$container_id:/openwrt/bin" "build"
docker rm "$container_id" > /dev/null
