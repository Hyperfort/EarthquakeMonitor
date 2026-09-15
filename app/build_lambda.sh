#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
build_dir="$project_dir/lambda_build"
artifact="$project_dir/ingestion.zip"

rm -rf "$build_dir" "$artifact"
mkdir -p "$build_dir"

uv pip install --target "$build_dir" pymysql requests
cp "$project_dir/lambda_ingestion.py" "$build_dir/"

cd "$build_dir"
zip -q -r "$artifact" .