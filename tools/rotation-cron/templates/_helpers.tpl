{{/*
Shared job body for both rotation CronJobs. Takes a dict with:
  Values       - the chart's .Values
  script       - path to the python rotation script, relative to repo root
  branchPrefix - branch name prefix (date suffix appended at run time)
  prTitle      - PR title

Uses `git add -A` against a fresh, disposable clone rather than a
hardcoded file list -- the infra-bundle-digest-rotation.yml workflow this
replaces already documented the exact failure mode of a hand-copied file
list drifting behind the script's own idea of what it touches (see that
workflow's history before it was deleted); a fresh clone makes `-A` safe.
*/}}
{{- define "rotation-cron.jobScript" -}}
set -euo pipefail

apt-get update -qq
apt-get install -y -qq git curl ca-certificates python3 >/dev/null

GH_VERSION="{{ .Values.ghCliVersion }}"
curl -fsSL -o /tmp/gh.tar.gz \
  "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_amd64.tar.gz"
tar -xzf /tmp/gh.tar.gz -C /tmp
install -m 0755 "/tmp/gh_${GH_VERSION}_linux_amd64/bin/gh" /usr/local/bin/gh

# Credentials via .netrc (mode 600) -- never interpolated into a URL that
# could get logged. printf, not a heredoc: Helm's nindent on this whole
# block indents every line including a heredoc terminator, which would
# stop it from matching and hang the job waiting for input.
{
  printf 'machine %s\n' "{{ .Values.git.host }}"
  printf 'login x-access-token\n'
  printf 'password %s\n' "${GIT_TOKEN}"
} > "${HOME}/.netrc"
chmod 600 "${HOME}/.netrc"

git clone --depth 50 "https://{{ .Values.git.host }}/{{ .Values.git.org }}/{{ .Values.git.repo }}.git" /tmp/repo
cd /tmp/repo
git config user.name "{{ .Values.git.commitUserName }}"
git config user.email "{{ .Values.git.commitUserEmail }}"

output="$(python3 {{ .script }})"
echo "$output"

if ! echo "$output" | grep -q '^changed=true$'; then
  echo "No change -- nothing to do."
  exit 0
fi

echo "$output" | sed -n '/-----PR-BODY-----/,/-----PR-BODY-----/p' | sed '1d;$d' > /tmp/pr-body.md

branch="{{ .branchPrefix }}-$(date +%Y%m%d)"
git checkout -b "$branch"
git add -A
git commit -m "{{ .prTitle }}"
git push -u origin "$branch"

export GH_HOST="{{ .Values.git.host }}"
export GH_ENTERPRISE_TOKEN="${GIT_TOKEN}"
gh pr create --repo "{{ .Values.git.org }}/{{ .Values.git.repo }}" \
  --title "{{ .prTitle }}" \
  --body-file /tmp/pr-body.md \
  --head "$branch"
{{- end -}}
