#!/usr/bin/env bash
# Run NetLogo commands headless: tools/nl.sh <model> < commands.txt
NL="C:/Program Files/NetLogo 7.0.4"
HERE="$(cd "$(dirname "$0")" && pwd -W)"
exec "$NL/runtime/bin/java.exe" -XX:MaxRAMPercentage=50 -Dfile.encoding=UTF-8 \
  "-Dnetlogo.models.dir=$NL/models" "-Dnetlogo.extensions.dir=$NL/extensions" \
  -cp "$NL/app/netlogo-7.0.4.jar;$HERE" NLRun "$1"
