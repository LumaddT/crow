#!/bin/bash
target="$PWD/crow/pb"
pb_dir="libcockatrice_protocol/libcockatrice/protocol/pb"
url="https://github.com/Cockatrice/Cockatrice"

cd "${BASH_SOURCE%/*}/" || exit 2

# find protoc
protoc="$PWD/protoc"
if [[ ! -x "$protoc" ]]; then
  protoc=protoc
  if ! hash "$protoc"; then
    echo "could not find protoc!" >&2
  fi
fi
version=$($protoc --version)
echo "Using $version"

# fetch source with git
tmp="$PWD/tmp"
src="$tmp/$pb_dir"
if [[ ! -d $src ]]; then
  git clone --depth 1 --sparse --filter=blob:none "$url" "$tmp"
  { cd "$tmp" && git sparse-checkout set "$pb_dir" ; }
else
  { cd "$tmp" && git pull ; }
fi

# compile
mkdir -p "$target"
"$protoc" -I="$src" --python_out="$target" "$src"/*.proto

# generate __init__.py
pyinit='"""'"Automatically generated protobuf library

This library is automatically generated from cockatrice source code at:
$url

Using protoc:
$version
"'"""
__all__ = ['
xpyfile='^[^_].*\.py$'
n="
"
cd "$target" || exit 2
export LC_COLLATE=C # no more localized globs
for file in *; do
  if [[ $file =~ $xpyfile ]]; then
    if [[ ! $first_found ]]; then
      first_found=1
    else
      pyinit+=","
    fi
    pyinit+="$n    '${file::-3}'"
  fi
done
if [[ ! $first_found ]]; then
  echo "no output files found, compilation failed" >&2
  exit 1
fi
pyinit+="
]


def do_import():
    import sys
    import os
    import importlib
    this_dir = os.path.dirname(os.path.abspath(__file__))
    back = [*sys.path]
    sys.path.insert(0, this_dir)
    for name in __all__:
        globals()[name] = importlib.import_module(name)

    sys.path = back


do_import()"
cat >"__init__.py" <<<"$pyinit"
