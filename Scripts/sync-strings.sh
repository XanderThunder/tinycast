#!/bin/bash
# Merge the strings the compiler extracted into Localizable.xcstrings, as an Xcode build in the IDE
# does; `xcodebuild` alone never writes them back. Run after changing any UI text.
set -euo pipefail
cd "$(dirname "$0")/.." || exit 1

DERIVED=build/strings
xcodebuild build -project Tinycast.xcodeproj -scheme Tinycast -configuration Debug \
    CODE_SIGNING_ALLOWED=NO -derivedDataPath "$DERIVED" -quiet

# A read loop rather than `mapfile`, which is bash 4 — macOS ships bash 3.2.
args=()
while IFS= read -r f; do args+=(--stringsdata "$f"); done < <(
    find "$DERIVED/Build/Intermediates.noindex/Tinycast.build/Debug/Tinycast.build" \
        -name '*.stringsdata'
)
# The catalog's file name is its table, so only `Localizable` strings land in it.
CATALOG=Tinycast/Resources/Localizable.xcstrings
xcrun xcstringstool sync "$CATALOG" "${args[@]}"

# English only, so a string no source extracts any more has nothing left to keep it.
node -e '
const fs = require("fs");
const path = process.argv[1];
const original = fs.readFileSync(path, "utf8");
const catalog = JSON.parse(original);
for (const [key, entry] of Object.entries(catalog.strings)) {
  if (entry.extractionState === "stale") delete catalog.strings[key];
}
// Written the way Xcode writes it, so a later save in the IDE is not a whole-file diff.
const format = (value, depth) => {
  const pad = "  ".repeat(depth);
  if (value === null || typeof value !== "object") return JSON.stringify(value);
  const entries = Array.isArray(value)
    ? value.map((item) => format(item, depth + 1))
    : Object.keys(value).map((key) => JSON.stringify(key) + " : " + format(value[key], depth + 1));
  const [open, close] = Array.isArray(value) ? ["[", "]"] : ["{", "}"];
  if (entries.length === 0) return open + "\n\n" + pad + close;
  return open + "\n" + entries.map((line) => pad + "  " + line).join(",\n") + "\n" + pad + close;
};
fs.writeFileSync(path, format(catalog, 0) + (original.endsWith("\n") ? "\n" : ""));
' "$CATALOG"
