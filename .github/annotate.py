"""Turns xcodebuild errors into GitHub annotations (readable from the checks API).
GitHub keeps 10 errors, 10 warnings and 10 notices per step, so each step reports
30 unique problems starting at the given offset."""
import re, sys

log, offset = sys.argv[1], int(sys.argv[2])
seen, problems = set(), []
pattern = re.compile(r"(error:|Test Case .* failed|XCTAssert|fatal error|Could not resolve|failed to)", re.I)
for line in open(log, errors="replace"):
    line = line.rstrip()
    if not pattern.search(line) or line in seen:
        continue
    seen.add(line)
    problems.append(line)

def clean(text):
    return text.replace("%", "%25").replace("\r", "").replace("\n", "%0A")[:900]

batch = problems[offset:offset + 30]
for i, text in enumerate(batch):
    level = ("error", "warning", "notice")[i // 10]
    m = re.match(r"(/[^:]+):(\d+):(?:\d+:)? *(?:error|warning)?:? *(.*)", text)
    if m:
        path = m.group(1).split("/AllSportsScoreboard/", 1)[-1] if "/AllSportsScoreboard/" in m.group(1) else m.group(1)
        print(f"::{level} title={clean(path)}:{m.group(2)}::{clean(m.group(3))}")
    else:
        print(f"::{level} title=log::{clean(text)}")
print(f"{len(problems)} problems total; reported {offset}..{offset + len(batch)}")
