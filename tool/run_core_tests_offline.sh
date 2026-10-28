#!/usr/bin/env bash
# Runs the sukkar_core analyzer and test suite WITHOUT pub.dev access, using the
# minimal package:test shim in tool/offline_test_shim. Normal machines should
# instead run:  cd packages/sukkar_core && dart pub get && dart test
#
# Usage: DART=/path/to/dart tool/run_core_tests_offline.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CORE="$ROOT/packages/sukkar_core"
SHIM="$ROOT/tool/offline_test_shim"
DART="${DART:-dart}"

mkdir -p "$CORE/.dart_tool"
cat > "$CORE/.dart_tool/package_config.json" <<EOF
{
  "configVersion": 2,
  "packages": [
    {"name": "sukkar_core", "rootUri": "../", "packageUri": "lib/", "languageVersion": "3.4"},
    {"name": "test", "rootUri": "file://$SHIM/", "packageUri": "lib/", "languageVersion": "3.4"}
  ],
  "generator": "run_core_tests_offline.sh"
}
EOF

echo "== dart analyze (core)"
(cd "$CORE" && "$DART" analyze --fatal-infos lib test)

echo "== tests"
AGG="$CORE/.dart_tool/all_tests.dart"
{
  echo "// Generated aggregator. Do not edit."
  i=0
  for f in "$CORE"/test/*_test.dart; do
    echo "import '../test/$(basename "$f")' as t$i;"
    i=$((i+1))
  done
  echo "import 'package:test/test.dart';"
  echo "void main() {"
  i=0
  for f in "$CORE"/test/*_test.dart; do
    echo "  group('$(basename "$f" .dart)', t$i.main);"
    i=$((i+1))
  done
  echo "}"
} > "$AGG"
cd "$CORE" && "$DART" --packages=.dart_tool/package_config.json "$AGG"
