#!/usr/bin/env bash
# Runs a CI command, keeps its output, and on failure publishes the log to the
# `ci-logs` branch (and as annotations) so it can be read without the web UI.
# Usage: tool/ci_step.sh <name> <command...>
set -uo pipefail
name="$1"; shift
mkdir -p "$RUNNER_TEMP/ci-logs"
log="$RUNNER_TEMP/ci-logs/${name}.log"
"$@" 2>&1 | tee "$log"
code=${PIPESTATUS[0]}
if [ "$code" -ne 0 ]; then
  grep -E "error|Error|FAILURE|Exception|Expected|failed" "$log" | head -40 | while IFS= read -r line; do
    echo "::error title=${name}::${line//%/%25}"
  done
  (
    set -e
    work="$RUNNER_TEMP/ci-logs-branch"
    rm -rf "$work" && mkdir -p "$work" && cd "$work"
    git init -q
    git config user.name "github-actions[bot]"
    git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
    cp "$RUNNER_TEMP"/ci-logs/*.log .
    echo "run ${GITHUB_RUN_ID} job ${GITHUB_JOB} step ${name} exit ${code}" > README.txt
    git add -A && git commit -qm "CI logs for run ${GITHUB_RUN_ID} (${GITHUB_JOB}/${name})"
    git push -qf "https://x-access-token:${GH_TOKEN}@github.com/${GITHUB_REPOSITORY}.git" HEAD:refs/heads/ci-logs-${GITHUB_JOB}
  ) || echo "could not publish logs"
fi
exit "$code"
