#!/bin/sh
# Syntax-check every script with the official Luau compiler (tools/bin/luau,
# unzipped from github.com/luau-lang/luau releases). Prints each error and
# exits 1 if there are any.
cd "$(dirname "$0")/.." || exit 1
bad=0
for f in $(find src -name "*.lua"); do
	out=$(tools/bin/luau/luau-compile.exe --text "$f" | grep "SyntaxError")
	if [ -n "$out" ]; then echo "$out"; bad=1; fi
done
[ $bad -eq 0 ] && echo "OK: no syntax errors"
exit $bad
