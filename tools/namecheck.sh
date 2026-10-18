#!/bin/sh
# Lists names the official Luau analyzer can't resolve, minus Roblox's
# built-ins: anything left is a typo, a missing local or a function used
# before it's defined. Prints nothing when all is well.
cd "$(dirname "$0")/.." || exit 1
ROBLOX="game|workspace|script|Enum|Instance|Vector3|Vector2|CFrame|Color3|UDim|UDim2|TweenInfo|NumberRange|NumberSequence|NumberSequenceKeypoint|ColorSequence|ColorSequenceKeypoint|RaycastParams|OverlapParams|Random|PhysicalProperties|Rect|Ray|BrickColor|Font|DateTime|task|warn|tick|time|typeof|Region3|Axes|Faces|utf8|debug|shared|settings|UserSettings|plugin|elapsedTime|delay|spawn|wait|version|ypcall|PathWaypoint|SharedTable|buffer|Content"
find src -name "*.lua" | xargs tools/bin/luau/luau-analyze.exe --formatter=plain 2>&1 \
	| grep "Unknown global" | grep -vE "Unknown global '($ROBLOX)'" | sed 's/ (W0) TypeError://'
