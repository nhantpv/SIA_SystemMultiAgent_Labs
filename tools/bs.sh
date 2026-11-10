#!/usr/bin/env bash
# Run a BehaviorSpace experiment headless: tools/bs.sh <model> <experiment> <table.csv>
# (NetLogo's netlogo-headless.bat breaks on the space in "Program Files" when called from Git Bash.)
NL="C:/Program Files/NetLogo 7.0.4"
exec "$NL/runtime/bin/java.exe" -XX:MaxRAMPercentage=50 -Dfile.encoding=UTF-8 \
  "-Dnetlogo.models.dir=$NL/models" "-Dnetlogo.extensions.dir=$NL/extensions" \
  -cp "$NL/app/netlogo-7.0.4.jar" org.nlogo.headless.Main --model "$1" --experiment "$2" --table "$3"
