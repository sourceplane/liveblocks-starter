#!/usr/bin/env bash
# TIER 2 — the product a bootstrap produces builds, migrates, deploys (dry)
# and serves.
#
# placement.test.sh proves the tree a bootstrap ends with is the right tree.
# This proves it WORKS, by doing to it what its own pipelines will:
#
#   1. at the 01-product landing (the commit its one pull request merges),
#      install with the lockfile the product ships, render the wrangler
#      fixture and check the committed config IS that render, typecheck,
#      lint, test, build. The landing's own PR runs `plan` alone (an
#      `orun/BASE-*` branch), so THIS is where a product those steps refuse
#      is caught: before the tag, not after a build has merged it;
#   2. the stage lanes' own steps, rendered by `orun plan` in the product and
#      run IN THE TREE THE RUNNER STAGES for each job (testing/lib/stage-job.py),
#      with the dependency layout the pinned composition produces and with the
#      job's secrets in its environment as the platform resolves them (the
#      component's secretEnv):
#      - web, from a pull request's plan (the verify profile: the deploy
#        profile has no dry run) — `verify-app-structure` (which checks the
#        wrangler config exists BEFORE anything is built), `build-app` (the
#        component's buildCommand: the live wiring render, then the build),
#        `verify-build-output` and `deploy-dry-run` (`wrangler deploy
#        --dry-run --name <reponame>-web-stage`), the database id in the built
#        config asserted to be the stage document's, not the fixture's;
#      - db-migrate: its install and build, the pull request's `plan` (offline,
#        every checksum verified), then the merge's `apply` — the step a push
#        to main runs — against a stand-in for D1's REST API over real SQLite
#        (testing/lib/d1-api.py), which refuses any account, database or token
#        but the ones the job resolves: the directory (users, organizations,
#        memberships), the kit's demo users and the generated session secret
#        created and every migration recorded; then the apply again, which
#        applies nothing;
#   3. serve the built Worker with `wrangler dev` (a local D1 behind the same
#      binding): with no schema the site cannot read its directory or its
#      secret and the component's OWN `smokeCommand` REFUSES it; after the
#      product's own `db:migrate:local` the smoke passes, verbatim — the check
#      the real deploy ends with. Then, with no Liveblocks project connected
#      (a fresh product): the marketing page carries the product's name and
#      links its repository, the demo sign-in signs a user in from D1, the
#      dashboard says Liveblocks is not connected, the room-auth action and
#      the webhook answer "not connected" and nothing is sent anywhere. And
#      then CONNECTED: the secret keys handed to the Worker the way the deploy
#      hands them (tooling/wire/worker-secrets.mjs, here as .dev.vars), the
#      site pointed at a stand-in Liveblocks API (testing/lib/liveblocks-api.py)
#      that refuses any key but the project's — the room-auth action mints a
#      token for the signed-in user and their organization, the dashboard's
#      query and a document page reach Liveblocks with the key, and the
#      webhook refuses an unsigned delivery and takes a signed one.
#
# What it cannot do is the platform's half: create the repository, mint the
# brokered Cloudflare tokens, apply the database, migrate it and deploy for
# real, and probe workers.dev. The D1 root is verified to `terraform validate`
# and its plan is part of every pull request's lanes; the apply needs an
# account.
#
# Needs: orun, node, pnpm, python3 (+PyYAML), git, curl, and the network for
# `pnpm install` and the build's Google Font (or a warm store). A few minutes:
# three installs and two builds.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"
# shellcheck source=lib/bootstrap.sh
source "$here/lib/bootstrap.sh"

for bin in orun node pnpm python3 git curl; do
  command -v "$bin" >/dev/null || { echo "e2e.test.sh needs $bin on PATH" >&2; exit 1; }
done

scratch="$(mktemp -d)"
dev_pid=""
api_pid=""
lb_pid=""
# wrangler dev runs under pnpm, node and two workerd processes; a TERM to the
# first does not reach the rest, and waiting on it then never returns. So it is
# started as its own process group (setsid) and the whole group is stopped.
stop_group() {
  kill -TERM -- "-$1" 2>/dev/null || true
  for _ in 1 2 3 4 5 6 7 8 9 10; do kill -0 -- "-$1" 2>/dev/null || break; sleep 0.5; done
  kill -KILL -- "-$1" 2>/dev/null || true
}
cleanup() {
  [ -z "$dev_pid" ] || stop_group "$dev_pid"
  [ -z "$api_pid" ] || stop_group "$api_pid"
  [ -z "$lb_pid" ] || stop_group "$lb_pid"
  rm -rf "$scratch"
}
trap cleanup EXIT
values="$here/fixtures/acme.json"
repo="$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['reponame'])" "$values")"
export CI=1 WRANGLER_SEND_METRICS=false NEXT_TELEMETRY_DISABLED=1 TURBO_TELEMETRY_DISABLED=1

# The landing's own checks, step for step: what a pull request in the product
# verifies through its lanes, run here at once on the whole tree.
LANDING_CHECKS=(
  "pnpm install --frozen-lockfile"
  "pnpm run wire:fixture"
  "git diff --exit-code"
  "pnpm typecheck"
  "pnpm lint"
  "pnpm test"
  "pnpm build"
)
checks() { # DIR LOG
  local dir="$1" log="$2" cmd
  for cmd in "${LANDING_CHECKS[@]}"; do
    echo "   \$ $cmd" | tee -a "$log"
    if ! (cd "$dir" && bash -c "$cmd") >> "$log" 2>&1; then
      echo "FAIL: \`$cmd\` failed in $dir" >&2; tail -40 "$log" >&2; return 1
    fi
  done
}

# A job's steps out of a plan, by component and environment: each step's
# script (named by its id, or by a fixed name for the composition steps this
# file runs), the job's path, its env and the names of its secrets.
extract() { # PLAN COMPONENT ENV OUTDIR
  python3 - "$@" <<'PY'
import json, pathlib, re, sys
plan, comp, env, out = json.load(open(sys.argv[1])), sys.argv[2], sys.argv[3], pathlib.Path(sys.argv[4])
out.mkdir(parents=True, exist_ok=True)
job = next(j for j in plan["jobs"] if j["component"] == comp and j["environment"] == env)
for s in job["steps"]:
    run = s.get("run") or ""
    if not run:
        continue
    sid = s["id"]
    if "dist/runner/cli.js apply" in run:
        sid = "migrate-apply"
    elif "dist/runner/cli.js plan" in run:
        sid = "migrate-plan"
    (out / f"{re.sub(r'[^A-Za-z0-9_-]', '_', sid)}.sh").write_text(run)
    if s["id"] in ("install-workspace-dependencies", "install-dependencies"):
        (out / "install.sh").write_text(run)
        (out / "install.wd").write_text(s.get("working-directory") or ".")
        (out / "install.scope").write_text(s.get("scope") or "job")
(out / "path").write_text(job.get("path") or ".")
(out / "env").write_text("".join(f"export {k}={json.dumps(v)}\n" for k, v in (job.get("env") or {}).items()))
(out / "secrets").write_text("\n".join(r["asEnv"] for r in job.get("secretRefs") or []))
PY
}

# A job's private tree, staged as orun stages it. The source checkout carries
# no build output (nothing was built in it), and its dependencies are what the
# pinned composition says: a lane-scoped install ran once in the source tree
# and is linked in, or the job installs its own.
stage_job() { # STEPS-DIR WORK-DIR LOG
  local steps="$1" work="$2" log="$3"
  [ -f "$steps/install.sh" ] || { echo "FAIL: the lane has no install step" >&2; return 1; }
  if [ "$(cat "$steps/install.scope")" = lane ]; then
    (cd "$tree" && bash -e "$steps/install.sh") > "$log" 2>&1 \
      || { echo "FAIL: the lane's install step" >&2; tail -30 "$log" >&2; return 1; }
    python3 "$here/lib/stage-job.py" "$tree" "$work" --shared-deps
    [ -L "$work/node_modules" ] || { echo "FAIL: the staged tree's node_modules is not the lane's symlink" >&2; return 1; }
    echo "   staged: $(realpath --relative-to="$tree" "$work"); install scope: lane — node_modules → the source tree's"
  else
    python3 "$here/lib/stage-job.py" "$tree" "$work"
    echo "   staged: $(realpath --relative-to="$tree" "$work"); install scope: job — installing inside it"
    (cd "$work/$(cat "$steps/path")/$(cat "$steps/install.wd")" && bash -e "$steps/install.sh") > "$log" 2>&1 \
      || { echo "FAIL: the lane's install step" >&2; tail -30 "$log" >&2; return 1; }
    [ -d "$work/node_modules" ] && [ ! -L "$work/node_modules" ] \
      || { echo "FAIL: the job's install did not land inside its own tree" >&2; return 1; }
  fi
}

# One step, in the runner's per-job environment: the job's env (intent
# environment `env:`), its resolved secrets (exported by the caller) and
# ORUN_ENVIRONMENT; the step runs in the component's directory.
run_step() { # STEPS-DIR WORK-DIR STEP LOG
  local steps="$1" work="$2" step="$3" log="$4"
  [ -f "$steps/$step.sh" ] || { echo "FAIL: the stage lane has no $step step" >&2; return 1; }
  echo "   ▸ $step"
  if ! (cd "$work/$(cat "$steps/path")" && source "$steps/env" && export ORUN_ENVIRONMENT=stage \
        && bash -e "$steps/$step.sh") > "$log" 2>&1; then
    echo "FAIL: the lane's $step step" >&2; tail -40 "$log" >&2; return 1
  fi
}

echo "── the offline bootstrap (testing/lib/bootstrap.sh)"
tree="$scratch/$repo"
bootstrap_offline "$root" "$tree" "$values" "$scratch/logs" > "$scratch/bootstrap.log" 2>&1 || {
  echo "FAIL: the offline bootstrap stopped" >&2; tail -40 "$scratch/bootstrap.log" >&2; exit 1; }
echo "   2 phases placed and landed"
s01="$(git -C "$tree" rev-parse HEAD~1)"

# ── 1. the product's one pull request ──────────────────────────────────────
echo "── 01-product's landing: install, the fixture render, typecheck, lint, test, build"
git -C "$tree" worktree add -q "$scratch/at-01" "$s01"
checks "$scratch/at-01" "$scratch/checks-01.log"
# The landing's build is done; its tree is not needed again, and the disk is shared.
git -C "$tree" worktree remove --force "$scratch/at-01"

# ── 2. the stage lanes' steps, in each job's own tree ─────────────────────
# A pull request that changes the site and the migration component: the lanes
# `orun plan` gives it. And the merge's plan, for the step only a merge runs.
git -C "$tree" checkout -q -b e2e-pr
echo "<!-- a change to the site's component -->" >> "$tree/apps/web/README.md"
echo "# a change to the migration component" >> "$tree/infra/db-migrate/component.yaml"
git -C "$tree" -c user.email=e2e@example.invalid -c user.name=e2e commit -qam "a pull request"
(cd "$tree" && orun plan --intent intent.yaml --trigger github-pull-request --changed \
   --base main --head HEAD --env stage --output "$scratch/plan.json") > "$scratch/plan.log" 2>&1 \
  || { echo "FAIL: orun plan (pull request)" >&2; tail -15 "$scratch/plan.log" >&2; exit 1; }
(cd "$tree" && orun plan --intent intent.yaml --trigger github-push-main --env stage \
   --output "$scratch/plan-main.json") > "$scratch/plan-main.log" 2>&1 \
  || { echo "FAIL: orun plan (push to main)" >&2; tail -15 "$scratch/plan-main.log" >&2; exit 1; }
extract "$scratch/plan.json" web stage "$scratch/web"
extract "$scratch/plan.json" db-migrate stage "$scratch/mig"
extract "$scratch/plan-main.json" db-migrate stage "$scratch/mig-main"

# What the platform resolves into the jobs before their first step: the
# wiring document the D1 root lease-published (the components' secretEnv),
# with a database id no fixture carries, so the built config and the
# migrated database prove which document they came from.
d1_id="5ca1ab1e-0000-4000-8000-00000000a001"
export WIRING_CLOUDFLARE_D1_STAGE='{"d1_database_id":"'"$d1_id"'","d1_database_name":"stg-'"$repo"'-stage"}'
export WIRING_CLOUDFLARE_D1_PROD='{"d1_database_id":"5ca1ab1e-0000-4000-8000-00000000a003","d1_database_name":"prod-'"$repo"'-prod"}'

echo "── the stage web lane: verify-app-structure, build-app, verify-build-output, deploy-dry-run"
for key in WIRING_CLOUDFLARE_D1_STAGE WIRING_CLOUDFLARE_D1_PROD; do
  grep -qx "$key" "$scratch/web/secrets" || { echo "FAIL: the stage web lane does not resolve $key" >&2; exit 1; }
done
work="$tree/.orun/runs/e2e/web.stage.verify-deploy/work"
stage_job "$scratch/web" "$work" "$scratch/install-web.log"
[ ! -e "$work/apps/web/.open-next" ] || { echo "FAIL: the staged tree carries build output" >&2; exit 1; }
for step in verify-app-structure build-app verify-build-output deploy-dry-run; do
  run_step "$scratch/web" "$work" "$step" "$scratch/$step.log"
done
grep -q "\"$d1_id\"" "$work/apps/web/wrangler.jsonc" \
  || { echo "FAIL: the lane's build did not render the stage database id from its wiring document" >&2; exit 1; }
# wrangler's dry run names a D1 binding's database by name, not id.
grep -Eq "env\.DB \(stg-$repo-stage\) +D1 Database" "$scratch/deploy-dry-run.log" \
  || { echo "FAIL: the dry run does not bind DB to the stage database" >&2; tail -20 "$scratch/deploy-dry-run.log" >&2; exit 1; }
echo "   the built config binds DB to the stage document's database ($d1_id); the dry run accepts it"

echo "── the stage db-migrate lane: install, build, the PR's plan, the merge's apply (a stand-in D1 API)"
for key in CLOUDFLARE_API_TOKEN CLOUDFLARE_ACCOUNT_ID WIRING_CLOUDFLARE_D1; do
  grep -qx "$key" "$scratch/mig-main/secrets" || { echo "FAIL: the stage db-migrate lane does not resolve $key" >&2; exit 1; }
done
[ -f "$scratch/mig/migrate-plan.sh" ] && [ ! -f "$scratch/mig/migrate-apply.sh" ] \
  || { echo "FAIL: a pull request's db-migrate lane must plan and not apply" >&2; ls "$scratch/mig" >&2; exit 1; }
[ -f "$scratch/mig-main/migrate-apply.sh" ] && [ ! -f "$scratch/mig-main/migrate-plan.sh" ] \
  || { echo "FAIL: the merge's db-migrate lane must apply" >&2; ls "$scratch/mig-main" >&2; exit 1; }
mwork="$tree/.orun/runs/e2e/db-migrate.stage.migrate/work"
stage_job "$scratch/mig" "$mwork" "$scratch/install-mig.log"
run_step "$scratch/mig" "$mwork" build-db-package "$scratch/mig-build.log"
run_step "$scratch/mig" "$mwork" migrate-plan "$scratch/mig-plan.log"
for id in 010_directory 020_demo_directory 030_app_secrets; do
  grep -q "\"$id\"" "$scratch/mig-plan.log" \
    || { echo "FAIL: the plan does not list $id as pending" >&2; cat "$scratch/mig-plan.log" >&2; exit 1; }
done
# The stand-in D1 API: only this account, this database (the stage
# document's id) and this token are answered.
(exec setsid python3 "$here/lib/d1-api.py" "$scratch/d1.sqlite" "$scratch/d1.port" \
   --account e2e-account --database "$d1_id" --token e2e-d1-token) > "$scratch/d1-api.log" 2>&1 < /dev/null &
api_pid=$!
for _ in $(seq 1 50); do [ -s "$scratch/d1.port" ] && break; sleep 0.1; done
[ -s "$scratch/d1.port" ] || { echo "FAIL: the stand-in D1 API did not start" >&2; cat "$scratch/d1-api.log" >&2; exit 1; }
export CLOUDFLARE_API_BASE_URL="http://127.0.0.1:$(cat "$scratch/d1.port")/client/v4"
# The job's own secrets: the D1 token as CLOUDFLARE_API_TOKEN, the account id,
# and this environment's wiring document.
for pass in first again; do
  (export CLOUDFLARE_API_TOKEN=e2e-d1-token CLOUDFLARE_ACCOUNT_ID=e2e-account \
          WIRING_CLOUDFLARE_D1="$WIRING_CLOUDFLARE_D1_STAGE" \
   && run_step "$scratch/mig-main" "$mwork" migrate-apply "$scratch/mig-apply-$pass.log") || exit 1
done
python3 - "$scratch/d1.sqlite" "$scratch/mig-apply-first.log" "$scratch/mig-apply-again.log" <<'PY'
import json, re, sqlite3, sys
db = sqlite3.connect(sys.argv[1])
def result(path):
    text = open(path).read()
    return json.loads(text[text.index("{"):text.rindex("}") + 1])
first, again = result(sys.argv[2]), result(sys.argv[3])
problems = []
ALL = ["000_control_baseline", "010_directory", "020_demo_directory", "030_app_secrets"]
if first["applied"] != ALL:
    problems.append(f"the first apply applied {first['applied']}")
if again["applied"] or again["skipped"] != ALL:
    problems.append(f"the second apply applied {again['applied']} and skipped {again['skipped']} — it must apply nothing")
counts = {t: db.execute(f"SELECT count(*) FROM {t}").fetchone()[0] for t in ("users", "organizations", "memberships")}
if counts != {"users": 5, "organizations": 6, "memberships": 10}:
    problems.append(f"the demo directory holds {counts}")
secret = db.execute("SELECT value FROM app_secrets WHERE name = 'auth'").fetchone()
if not secret or not re.fullmatch(r"[0-9a-f]{64}", secret[0]):
    problems.append(f"the generated session secret is {secret}")
ledger = [r[0] for r in db.execute("SELECT id FROM _migrations_applied ORDER BY id")]
if ledger != ALL:
    problems.append(f"the ledger records {ledger}")
for p in problems:
    print(f"  ✕ {p}", file=sys.stderr)
sys.exit(1 if problems else 0)
PY
grep -q 'POST /client/v4/accounts/e2e-account/d1/database/'"$d1_id"'/query' "$scratch/d1-api.log" \
  || { echo "FAIL: the runner did not call the stage database's query endpoint" >&2; exit 1; }
echo "   the stage document's database: the directory, the kit's 5 demo users and a generated session secret,"
echo "   every migration recorded; the second apply applied nothing"
stop_group "$api_pid"; api_pid=""
unset CLOUDFLARE_API_BASE_URL


# ── 3. serve it, and smoke it as the deploy does ───────────────────────────
start_dev() { # LOG
  port=$(python3 -c "import socket;s=socket.socket();s.bind(('127.0.0.1',0));print(s.getsockname()[1]);s.close()")
  (cd "$work/apps/web" && exec setsid pnpm exec wrangler dev --config wrangler.jsonc --ip 127.0.0.1 --port "$port" \
     --name "$repo-web-stage" --show-interactive-dev-session=false) > "$scratch/$1.log" 2>&1 < /dev/null &
  dev_pid=$!
  url="http://127.0.0.1:$port"
  for _ in $(seq 1 90); do
    curl -s -o /dev/null "$url/icon.svg" && break
    kill -0 "$dev_pid" 2>/dev/null || { echo "FAIL: wrangler dev exited" >&2; tail -30 "$scratch/$1.log" >&2; exit 1; }
    sleep 1
  done
  curl -s -o /dev/null "$url/icon.svg" || { echo "FAIL: wrangler dev never answered" >&2; tail -30 "$scratch/$1.log" >&2; exit 1; }
}
echo "── wrangler dev over the built Worker (a local D1 behind DB), no Liveblocks project connected"
start_dev dev
smoke="$(python3 -c "import yaml,sys;print(yaml.safe_load(open(sys.argv[1]))['spec']['parameters']['smokeCommand'])" "$tree/apps/web/component.yaml")"

echo "   ▸ no schema yet: no directory and no session secret — the health route fails, and the deploy's smoke refuses it"
code="$(curl -s -o /dev/null -w '%{http_code}' "$url/api/health")"
[ "$code" = 500 ] || { echo "FAIL: /api/health answered $code without the users table, not 500" >&2; exit 1; }
if DEPLOYED_URL="$url" bash -c "$smoke"; then
  echo "FAIL: the deploy's smoke passed a site that could not read its database" >&2; exit 1
fi

echo "   ▸ the product's own db:migrate:local, then the component's own smokeCommand, DEPLOYED_URL=$url"
(cd "$work/apps/web" && pnpm run db:migrate:local) > "$scratch/migrate-local.log" 2>&1 \
  || { echo "FAIL: db:migrate:local" >&2; tail -20 "$scratch/migrate-local.log" >&2; exit 1; }
DEPLOYED_URL="$url" bash -c "$smoke" || { echo "FAIL: the deploy's smoke refused the migrated site" >&2; exit 1; }

# The routes, and the demo sign-in through D1, as a browser makes them. One
# script for both passes: CONNECTED says which.
cat > "$scratch/routes.py" <<'PY'
import base64, hashlib, hmac, html, http.cookiejar, json, os, re, subprocess, sys, time, urllib.error, urllib.parse, urllib.request
base, values, app, action, connected = sys.argv[1], json.load(open(sys.argv[2])), sys.argv[3], sys.argv[4], sys.argv[5] == "1"
name, repo, org = values["productname"], values["reponame"], values["githuborg"]
problems = []
def bad(m): problems.append(m)
class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *a, **k): return None
def client(follow=True):
    jar = http.cookiejar.CookieJar()
    handlers = [urllib.request.HTTPCookieProcessor(jar)] + ([] if follow else [NoRedirect()])
    return urllib.request.build_opener(*handlers), jar
def get(opener, path, data=None, headers=None):
    req = urllib.request.Request(base + path, data=data, headers=headers or {})
    try:
        with opener.open(req, timeout=30) as r:
            return r.status, r.headers, r.read().decode(errors="replace"), r.geturl()
    except urllib.error.HTTPError as e:
        return e.code, e.headers, e.read().decode(errors="replace"), base + path
def text(fragment): return html.unescape(re.sub(r"<[^>]+>", "", fragment)).strip()
def sign_in(email):
    opener, jar = client()
    _, _, body, _ = get(opener, "/api/auth/csrf")
    form = urllib.parse.urlencode({"csrfToken": json.loads(body)["csrfToken"], "email": email,
                                   "callbackUrl": base + "/dashboard"}).encode()
    nr = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(jar), NoRedirect())
    status, headers, _, _ = get(nr, "/api/auth/callback/credentials", data=form,
                                headers={"content-type": "application/x-www-form-urlencoded"})
    _, _, body, _ = get(opener, "/api/auth/session")
    return opener, jar, status, headers.get("location", ""), (json.loads(body) if body.strip() not in ("", "null") else None)
def act(fn, args, jar=None):
    env = dict(os.environ)
    if jar is not None:
        env["COOKIE"] = "; ".join(f"{c.name}={c.value}" for c in jar)
    r = subprocess.run(["node", action, base, fn, "--args", json.dumps(args)], cwd=app, capture_output=True, text=True, env=env)
    lines = r.stdout.strip().splitlines()
    if r.returncode != 0 or len(lines) < 2:
        bad(f"{fn} answered {r.stdout.strip() or r.stderr.strip()}")
        return None
    return json.loads(lines[1])

anon, _ = client()
status, _, page, _ = get(anon, "/")
if status != 200:
    bad(f"/ answered {status}")
title = re.search(r"<title>(.*?)</title>", page, re.S)
if not title or text(title.group(1)) != name:
    bad(f"the page's <title> is {title and title.group(1)!r}, not {name!r}")
links = re.findall(r'href="(https://github\.com/[^"]*)"', page)
if links != [f"https://github.com/{org}/{repo}"]:
    bad(f"the page's repository links are {links}, not github.com/{org}/{repo}")
if name not in text(page):
    bad("the footer does not carry the product's name")
if "liveblocks-starter" in page:
    bad("the page still carries the baseline's slug")
status, _, page, _ = get(anon, "/signin")
if status != 200:
    bad(f"/signin answered {status}")
status, _, body, _ = get(anon, "/api/auth/providers")
if status != 200 or "credentials" not in json.loads(body):
    bad(f"/api/auth/providers answered {status} {body[:200]}")
for path, want, ctype in (("/icon.svg", 200, "image/svg"), ("/no-such-page", 404, "text/html")):
    s, h, _, _ = get(anon, path)
    if s != want or not (h.get("content-type") or "").startswith(ctype):
        bad(f"{path} answered {s} {h.get('content-type')}, want {want} {ctype}")
# Signed out, the dashboard sends a visitor home.
nr, _ = client(follow=False)
s, h, _, _ = get(nr, "/dashboard")
if s not in (302, 303, 307) or urllib.parse.urlparse(h.get("location", "")).path not in ("", "/"):
    bad(f"signed out, /dashboard answered {s} → {h.get('location')}, not a redirect home")

# THE DIRECTORY, FROM D1: the kit's demo sign-in takes a user the database holds,
# with their organizations in order, and refuses one it does not.
user, jar, status, location, session = sign_in("mislav.abha@example.com")
if not session or session["user"]["info"]["id"] != "mislav.abha@example.com" \
        or session["user"]["info"]["organizationIds"] != ["liveblocks", "mislav.abha@example.com"] \
        or session["user"].get("currentOrganizationId") != "liveblocks":
    bad(f"the demo sign-in's session is {session}")
_, _, _, _, nobody = sign_in("nobody@example.com")
if nobody:
    bad(f"an email the directory does not hold signed in: {nobody}")
users = act("getUsers", [{"search": "an"}], jar)
if users is not None and [u and u["id"] for u in users] != ["anjali.wanda@example.com"]:
    bad(f"getUsers({{search: 'an'}}) answered {users}")

health = json.loads(get(anon, "/api/health")[2])
want = {"ok": True, "users": 5, "liveblocks": "connected" if connected else "not-connected"}
if health != want:
    bad(f"/api/health answered {health}, not {want}")

status, _, page, _ = get(user, "/dashboard")
marker = 'data-liveblocks="not-connected"' in page
if status != 200 or marker == connected:
    bad(f"signed in, /dashboard answered {status} with{'' if marker else 'out'} the not-connected notice")
if not connected and "Liveblocks is not connected" not in text(page):
    bad("the not-connected dashboard does not say so")

auth = act("authorizeLiveblocks", [None], jar)
webhook_body = json.dumps({"type": "storageUpdated", "data": {"roomId": "e2e-room", "projectId": "p", "updatedAt": "2026-10-28T00:00:00.000Z"}})
if not connected:
    err = (auth or {}).get("error") or {}
    if err.get("code") != 503 or err.get("message") != "Liveblocks is not connected" \
            or "LIVEBLOCKS_SECRET_KEY" not in err.get("suggestion", ""):
        bad(f"not connected, the room-auth action answered {auth}")
    s, _, body, _ = get(anon, "/api/notifications/email", data=webhook_body.encode(), headers={"content-type": "application/json"})
    if s != 503:
        bad(f"not connected, the webhook answered {s} {body[:120]}")
else:
    if auth != {"data": {"token": "e2e.id.token"}}:
        bad(f"connected, the room-auth action answered {auth}")
    docs = act("getDocuments", [{"limit": 5}], jar)
    if not docs or docs.get("data", {}).get("documents") != []:
        bad(f"connected, getDocuments answered {docs}")
    s, _, page, _ = get(user, "/text/e2e-room")
    if s != 200:
        bad(f"connected, a document page answered {s}")
    # Liveblocks' webhook: an unsigned delivery is refused, a signed one taken.
    s, _, body, _ = get(anon, "/api/notifications/email", data=webhook_body.encode(), headers={"content-type": "application/json"})
    if s != 400:
        bad(f"an unsigned webhook delivery answered {s} {body[:120]}")
    secret = os.environ["E2E_WEBHOOK_SECRET"]
    wid, ts = "msg_e2e", str(int(time.time()))
    sig = base64.b64encode(hmac.new(base64.b64decode(secret.split("_", 1)[1]), f"{wid}.{ts}.{webhook_body}".encode(), hashlib.sha256).digest()).decode()
    s, _, body, _ = get(anon, "/api/notifications/email", data=webhook_body.encode(),
                        headers={"content-type": "application/json", "webhook-id": wid, "webhook-timestamp": ts, "webhook-signature": f"v1,{sig}"})
    if s != 200 or "Event type not used" not in body:
        bad(f"a signed webhook delivery answered {s} {body[:120]}")

if problems:
    for p in problems:
        print(f"  ✕ {p}", file=sys.stderr)
    sys.exit(1)
PY

echo "   ▸ every route the site promises, the demo sign-in through D1, and Liveblocks not connected"
python3 "$scratch/routes.py" "$url" "$values" "$work/apps/web" "$here/lib/server-action.mjs" 0 \
  || { echo "FAIL: the routes, not connected" >&2; tail -20 "$scratch/dev.log" >&2; exit 1; }
echo "   / (the product's name, its repository), /signin, a demo user signed in from D1 (and an unknown one"
echo "   refused), /api/health, the dashboard's not-connected notice, the room-auth action and the webhook"
echo "   answering 'not connected' — with no request sent to anyone"
stop_group "$dev_pid"; dev_pid=""

echo "── connected: Liveblocks' keys handed to the Worker as the deploy hands them, against a stand-in Liveblocks API"
key="sk_dev_e2e_offline_fixture_not_a_key"
export E2E_WEBHOOK_SECRET="whsec_$(python3 -c 'import base64,os;print(base64.b64encode(os.urandom(24)).decode())')"
(exec setsid python3 "$here/lib/liveblocks-api.py" "$scratch/lb.port" "$scratch/lb.log" --key "$key") \
  > "$scratch/lb-api.log" 2>&1 < /dev/null &
lb_pid=$!
for _ in $(seq 1 50); do [ -s "$scratch/lb.port" ] && break; sleep 0.1; done
[ -s "$scratch/lb.port" ] || { echo "FAIL: the stand-in Liveblocks API did not start" >&2; cat "$scratch/lb-api.log" >&2; exit 1; }
# The product's own secrets push, writing what `wrangler secret bulk` would
# receive as the local Worker's secrets — and where the API is.
(cd "$work/apps/web" && LIVEBLOCKS_SECRET_KEY="$key" LIVEBLOCKS_WEBHOOK_SECRET_KEY="$E2E_WEBHOOK_SECRET" \
   node ../../tooling/wire/worker-secrets.mjs --secret LIVEBLOCKS_SECRET_KEY --secret LIVEBLOCKS_WEBHOOK_SECRET_KEY \
   --dev-vars .dev.vars) > "$scratch/dev-vars.log" 2>&1 \
  || { echo "FAIL: worker-secrets.mjs --dev-vars" >&2; cat "$scratch/dev-vars.log" >&2; exit 1; }
echo "LIVEBLOCKS_BASE_URL=\"http://127.0.0.1:$(cat "$scratch/lb.port")\"" >> "$work/apps/web/.dev.vars"
start_dev dev-connected
DEPLOYED_URL="$url" bash -c "$smoke" || { echo "FAIL: the deploy's smoke refused the connected site" >&2; exit 1; }
python3 "$scratch/routes.py" "$url" "$values" "$work/apps/web" "$here/lib/server-action.mjs" 1 \
  || { echo "FAIL: the routes, connected" >&2; tail -20 "$scratch/dev-connected.log" >&2; exit 1; }
python3 - "$scratch/lb.log" <<'PY'
import json, sys
calls = [json.loads(l) for l in open(sys.argv[1])]
problems = []
if not calls or not all(c["key"] for c in calls):
    problems.append(f"a request reached Liveblocks without the project's key: {[c for c in calls if not c['key']]}")
ident = [json.loads(c["body"]) for c in calls if c["path"] == "/v2/identify-user"]
if not ident or ident[0].get("userId") != "mislav.abha@example.com" or ident[0].get("groupIds") != ["liveblocks"] \
        or ident[0].get("organizationId") != "liveblocks":
    problems.append(f"identify-user was {ident}")
if not any(c["path"].startswith("/v2/rooms?") for c in calls):
    problems.append("the dashboard's query never reached Liveblocks")
if not any(c["path"] == "/v2/rooms/e2e-room" for c in calls):
    problems.append("the document page never asked Liveblocks for its room")
for p in problems:
    print(f"  ✕ {p}", file=sys.stderr)
sys.exit(1 if problems else 0)
PY
echo "   the smoke, the routes and the demo sign-in again; the room-auth action minted a token for the signed-in"
echo "   user in their organization, the dashboard's query and a document page reached Liveblocks with the"
echo "   project's key (and never without it), an unsigned webhook was refused and a signed one taken"
stop_group "$dev_pid"; dev_pid=""
stop_group "$lb_pid"; lb_pid=""

echo "e2e.test.sh: ok"
