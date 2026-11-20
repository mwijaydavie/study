#!/usr/bin/env bash
# Keep the command's exit status and surface a bounded, readable diagnostic in
# GitHub's check annotations, which are available independently of the log ZIP.
set -euo pipefail
log=$(mktemp)
trap 'rm -f "$log"' EXIT
if "$@" 2>&1 | tee "$log"; then
  exit 0
else
  status=$?
fi
python3 - "$log" <<'PY'
import re
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(errors="replace")
text = re.sub(r"\x1b\[[0-?]*[ -/]*[@-~]", "", text)
lines = [line for line in text.splitlines() if line.strip()]
# Include compiler/Flutter/Gradle errors plus the tail, bounded to one annotation.
important = [line for line in lines if re.search(
    r"(?:\berror\b|\bwarning\b|\bexception\b|\[E\]|failed|what went wrong|issue.*found)", line, re.I
)]
# Flutter test failures print the expected/actual values and stack immediately
# after this banner, before the other test files finish and displace the tail.
failed_tests = [line for line in lines if ".dart:" in line and line.endswith(" [E]")]
assertions = []
for index, line in enumerate(lines):
    if not re.match(r"^═+╡ EXCEPTION CAUGHT\b", line):
        continue
    excerpt = []
    for item in lines[index + 1:index + 80]:
        if item.startswith("═") or re.match(r"^\d+:\d+ [+]\d+", item):
            break
        excerpt.append(item)
    details = [item for item in excerpt if "/test/" in item or "package:studydesk/" in item or re.match(r"^#0\s", item)]
    report = "\n".join([line, *excerpt[:7], *details[:3]])
    if report not in assertions:
        assertions.append(report)
    if len(assertions) >= 7:
        break
message = "\n".join(dict.fromkeys([*failed_tests, *assertions, *important[:18], *lines[-12:]])) or "Command failed without output."
message = message[:11000].replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")
print(f"::error::{message}")
PY
exit "$status"
