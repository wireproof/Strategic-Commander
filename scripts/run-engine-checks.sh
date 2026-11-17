#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
test_binary="$(mktemp -t strategic-engine-checks)"
trap 'rm -f "$test_binary"' EXIT
swiftc -parse-as-library Sources/GameState.swift Sources/GalaxyLayout.swift Sources/FacilityAccounting.swift Sources/PlanetProduction.swift Sources/Game.swift Tests/EngineChecks.swift -o "$test_binary"
"$test_binary"
