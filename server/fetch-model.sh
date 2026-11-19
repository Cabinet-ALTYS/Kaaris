#!/bin/sh
set -eu

cd "$(dirname "$0")"
case "${1:-e4b}" in
  e4b)
    repository=google/gemma-4-E4B-it-qat-q4_0-gguf
    revision=4b4a2c1d584be7264f87aac328a1bc739ce81b6c
    filename=gemma-4-E4B_q4_0-it.gguf
    size=5154941280
    digest=676c35070db6dbe52f93e9c864ee0fba4eddea94b9c875d9cb10daff453fbaee
    ;;
  e2b)
    repository=google/gemma-4-E2B-it-qat-q4_0-gguf
    revision=675cff42a74c774d6cb76f76d8eacb49b48c9b93
    filename=gemma-4-E2B_q4_0-it.gguf
    size=3349516256
    digest=fa401b55b07ee70a54c6dae3903c783a6e65064312529ea57175cb5f8dec6634
    ;;
  *)
    printf 'Usage: sh fetch-model.sh [e4b|e2b]\n' >&2
    exit 2
    ;;
esac

mkdir -p models
model="models/$filename"
partial="$model.part"

verify() {
  printf '%s  %s\n' "$digest" "$1" | sha256sum --check -
}

if [ -f "$model" ]; then
  verify "$model"
  exit
fi

if [ ! -f "$partial" ] || [ "$(wc -c < "$partial")" -lt "$size" ]; then
  curl --fail --location --retry 4 --continue-at - --output "$partial" \
    "https://huggingface.co/$repository/resolve/$revision/$filename"
fi

verify "$partial"
mv "$partial" "$model"
