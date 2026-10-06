# Issue #11 traceability ledger

Tracks every review requirement for PR #13 (Phase 3) and PR #14 (Phase 2):
where it was implemented (commit) and how it was proven (test IDs, result).
Not part of any PR. Raw outputs live in `tests/results/` as
`phase{2,3}-S<step>-<timestamp>.txt`.

Test host: WSL Ubuntu-26.04, KVM, 3 UEFI nodes (main, secondary, secondary-1).
Upgrade baselines: `v1.1.2` (release, transient nodes + dnsmasq), `origin/main` (`1fc2922`).

## PR #13 - Phase 3, declarative VM lifecycle

Branch `feat/11-phase3-vm-template-units`, base `origin/main` `1fc2922`.
Pre-existing commits: `81c2c90` (template units), `5cde6e0` (man page).

| Req | Requirement | Step | Commit | Tests | Result |
|-----|-------------|------|--------|-------|--------|
| R0-3 | `del_nat` must not end cleanup early | S3.1 | `676603b` | T3.8 | PASS |
| R0-1 | Every wait is bounded | S3.2 | `825810b` | T3.H | PASS |
| R0-2 | Helpers never touch caller traps | S3.2 | `825810b` | T3.H | PASS |
| R13-1 | Keep `BindsTo=aos-unit.service` | S3.3 | `21fc40b` | T3.1, T3.2 | PASS (S3.8 regression) |
| R13-2 | Remove `After=aos-unit.service` | S3.3 | `21fc40b` | T3.1, T3.2 | PASS (S3.8 regression) |
| R13-3 | Runner owns node-start gate | S3.3 | `21fc40b` | T3.3 | PASS (S3.8 regression) |
| R13-4 | Template conditions, `-` env files, ExecCondition | S3.3 | `21fc40b` | T3.1, T3.2, T3.3 | PASS (S3.8 regression) |
| R13-5 | Transient dnsmasq untouched, no After=dnsmasq | S3.8 audit | n/a | A3.1 | PASS: `git diff 1fc2922 e0051aa` has no dnsmasq/systemd-run lines; `node@` has no `After=` |
| R13-6 | Keep vm-launch, env files, set-property | S3.8 audit | `81c2c90` | T3.1 limits | PASS (cgroup limits in T3.1) |
| R13-7 | Static cleanup by ActiveState only | S3.4 | `32c4494` | T3.5 | PASS (S3.8 regression) |
| R13-8 | Migrate legacy `aos-unit-node-*` transient units | S3.5 | `8f0739c` | T3.6 | PASS (reruns from v1.1.2 and main) |
| R13-9 | Restart policy decided by failure matrix | S3.6 | `57f2627` (tag), `1556cd1` (decision) | T3.4 | PASS: on-failure kept; teardown identical under both policies thanks to the gate, on-failure also retries exit-code/OOM/ExecStartPre failures up to StartLimitBurst |
| R13-10 | Network orchestration otherwise unchanged | S3.8 audit | n/a | A3.1 | PASS: only `network-helper` cleanup (bounded node wait, gate, `del_nat`) and `runner` changed; `service-startup`, `service-cleanup`, `aos-unit.service` identical to main |
| (pkg) | No maintscript start/stop for `aos-unit-node@` | S3.8 | n/a | T3.7 | PASS (maintscripts name `aos-unit.service`, `aos-unit.slice` only; `dpkg -r` while running is clean) |
| (docs) | Gated lifecycle in README / man / polkit | S3.7 | `e0051aa` | `man --warnings` | PASS |

## PR #14 - Phase 2, declarative network sidecar

Rework branch `feat/11-phase2-rework`, stacked on PR #13 head `e0051aa`.
It replaces PR #14's branch `feat/11-phase2-dnsmasq-static-unit` at publish
time (published head on the fork `cb28236`; unpublished local rewrite
`0c23da8` + `12d42a0` left untouched; `cb28236` and `0c23da8` differ only in
README/man wording). Commits:
`dcb611e` (static unit, port of `0c23da8`), `950e70d` (S2.1), `d5d74de` (S2.2),
`4d06c73` (S2.3), `370e4cf` (S2.4), `79990ec` (S2.5), `7bf97eb` (S2.6 docs).

| Req | Requirement | Step | Commit | Tests | Result |
|-----|-------------|------|--------|-------|--------|
| R14-1 | No `PropagatesStopTo=`; cleanup owns dnsmasq stop | S2.1 | `950e70d` | T2.1, T2.2 | PASS (restart x2 gives a new dnsmasq PID each time; stop is clean) |
| R14-2 | Teardown order nodes -> dnsmasq -> network | S2.1 | `950e70d` | T2.2 | PASS (journal anchors; also with a SIGSTOPped guest: dnsmasq stays active ~58 s until it is killed) |
| R14-7 | Node delta only `After=` the sidecar (see D-1) | S2.2 | `d5d74de`, `4d06c73` | T2.1, T3.1 | PASS |
| R14-3 | Transient -> static dnsmasq migration, bounded | S2.3 | `4d06c73` | T2.3 | PASS: lingering legacy migrated on first start; stuck legacy fails start after 31 s (15 s + 15 s cleanup), self-heals |
| R14-4 | Real upgrade: first start OK, `Transient=no` | S2.3 | `4d06c73` | T2.3 | PASS from Phase 3 deb (migration fired, no manager restart) and from v1.1.2 (F-1 self-heal only) |
| R14-5 | Debian manages only `aos-unit.service` | S2.4 | `370e4cf` | T2.4 | PASS (maintscripts name only `aos-unit.service`; `dpkg -r` while running is clean) |
| R14-6 | `dpkg-deb -e` grep finds no dnsmasq actions | S2.4 | `370e4cf` | T2.4 | before: `prerm`/`postinst` stop/restart `aos-unit-dns.service` + `aos-unit.slice` at `4d06c73`; after: only `aos-unit.service` (`inspect-maintscripts.sh`) |
| R14-8 | Drop remaining transient machinery | S2.5 | `79990ec` | T2.5 | PASS at `79990ec` (SIGKILL, SIGSTOP, port taken, leftover failed: each ends in a clean stop and a clean next start). At `7bf97eb` T2.5c (port taken) ended with `aos-unit.service` failed in 2 of 2 runs: F-2, runner exit 143; teardown complete and the next start clean. `runner` is identical in both builds. |
| (docs) | Sidecar ownership, order, new name | S2.6 | `7bf97eb` | `man --warnings` | PASS |

### Deviations

| ID | Deviation | Why | Evidence |
|----|-----------|-----|----------|
| D-1 | The static sidecar ships as `aos-unit-dns.service`, not under the transient name `aos-unit-dnsmasq.service`. Migration follows the review's rule unchanged: stop the transient `aos-unit-dnsmasq`, wait for `LoadState=not-found`, start the static unit. | `debhelper` runs `daemon-reload` while the old transient is still loaded, so systemd maps the name to the transient file; once collected, the name stays `not-found` until the next `daemon-reload`, which the `aos-unit` user cannot run. A same-name static unit fails its first start after every upgrade from a running transient release. User decision 2026-10-02. | `probe-transient-shadow.sh` |
| D-2 | `wait_for_unit_inactive` is used for the static sidecar; `wait_for_unit_unloaded` only for the legacy transient. | Static units never reach `not-found`. | T2.1, T2.2 |

## Test runs

| Step | Package | Tests | Result |
|------|---------|-------|--------|
| S3.0 before | `5cde6e0` | T3.1 | FAIL (3): `Result: resources` / missing env file on every restart; proves the `After=`+`BindsTo=` race |
| S3.2 | `825810b` log-helper | T3.H (H1-H7) | PASS |
| S3.1 | `676603b` | T3.8 | PASS |
| S3.3 | `21fc40b` | T3.1, T3.2 x10, T3.3 | T3.2, T3.3 PASS; T3.1 1 FAIL = harness (journal window caught the pre-test teardown in the same second) |
| S3.4 | `32c4494` | T3.5, T3.1 | PASS |
| S3.5 | `8f0739c` from v1.1.2 | T3.6 | migration checks PASS; journal FAIL = pre-existing v1.1.2 -> main self-heal (see findings) |
| S3.5 | `8f0739c` from main | T3.6 | migration checks PASS; harness FAILs (NRestarts reset by explicit restart, stop before guest boot); runner exit 143 once (see findings) |
| S3.3 rerun | `21fc40b` | T3.1 | PASS (harness: 1.1 s boundary after clean slate) |
| S3.5 rerun | `8f0739c` from v1.1.2 | T3.6 | PASS (F-1 lines INFO via `KNOWN_V112_SELF_HEAL=1`) |
| S3.5 rerun | `8f0739c` from main | T3.6 | PASS (restart count from journal, stop after guest boot) |
| S3.6 | `57f2627` | T3.4 M1-M9 x {on-failure, on-abort} | PASS |
| S3.8 | `e0051aa` | T3.1, T3.2 x10, T3.3, T3.5, T3.8 | PASS (236 checks) |
| S3.8 | `e0051aa` log-helper | T3.H | PASS |
| S3.8 | `e0051aa` deb | T3.7 + `dpkg -r` while running | PASS |
| S3.8 | `e0051aa` from main | T3.6 | PASS |
| S3.8 | `e0051aa` from v1.1.2 | T3.6 | 1 FAIL = harness: F-1 signature did not allow the `(during manager stop)` tag added by `57f2627`; same 3 legacy guests as F-1 |
| S3.8 rerun | `e0051aa` from v1.1.2 | T3.6 | PASS |
| S2.3 | `4d06c73` from v1.1.2 | T2.3 | PASS |
| S2.3 | `4d06c73` from Phase 3 (`e0051aa`) | T2.3 | PASS |
| S2.4 | `370e4cf` deb | T2.4 + `dpkg -r` while running | PASS |
| S2.5 | `79990ec` | T2.1, T2.2, T2.5 | T2.5 PASS; 3 FAIL = harness: T2.2 read unit timestamps after GC (all 0), T2.1 restarted before guests booted (F-3) |
| S2.5 rerun | `79990ec` | T2.1, T2.2, T2.3a/b | PASS |
| S2.7 | `7bf97eb` | T2.1, T2.2, T2.3a/b, T2.5 | 2 FAIL in T2.5c = F-2 (runner exit 143 on a stop 4 s after the route monitor started; teardown itself correct and complete); everything else PASS |
| S2.7 | `7bf97eb` | T3.1, T3.2 x10, T3.3, T3.5, T3.8 | PASS |
| S2.7 | `7bf97eb` log-helper | T3.H | PASS |
| S2.7 | `7bf97eb` deb | T2.4 + `dpkg -r` while running | PASS |
| S2.7 | `7bf97eb` from v1.1.2 | T2.3 | PASS (F-1 self-heal only) |
| S2.7 | `7bf97eb` from main | T2.3 | PASS (dnsmasq migration fired) |
| S2.7 | `7bf97eb` from Phase 3 | T2.3 | PASS (dnsmasq migration fired, no manager restart) |
| S2.7 rerun | `7bf97eb` | T2.5 | T2.5c: same 2 FAIL = F-2 again; T2.5a/b/d PASS |
| F-2 probe | `7bf97eb` | 8 x (start, 5 s, stop), no port holder | 0/8 exit 143 |

## Findings outside the review's list

| ID | Finding | Scope | Evidence |
|----|---------|-------|----------|
| F-1 | Upgrading a running v1.1.2: new `network-helper` requires `DHCP_START` (main `2c17366`) but the old runtime `network.conf` lacks it, so the old instance's cleanup aborts, the first new start fails "Bridge already exists", and `Restart=on-failure` heals it on the second start. | Pre-existing on main, not caused by Phase 3 | `phase3-S3.5-from-v1.1.2-*`, journal 53680-53692 |
| F-2 | `runner` exits 143 on SIGTERM while blocked in the route-monitor `read` (bash logs `Terminated IFS= read -r -u ...`, then the EXIT trap runs), leaving `aos-unit.service` failed after an otherwise complete teardown. Seen 4 times: 0.6 s after monitor start (S3.5), 18.6 s (S3.8 `dpkg -r`), and 4 s in T2.5c twice in a row (3 of 133 stops on 2026-10-02). Not triggered by an early stop alone (0/8, `probe-early-stop.sh`); T2.5c's busy DNS port with a crash-looping sidecar makes it frequent. `origin/main` has the identical structure (`set -Eeuo pipefail`, `trap 'exit 0' INT TERM`, EXIT trap kill+wait on the coproc). Not reproduced in 28 + 120 isolated probes on bash 5.3.9 (`probe-runner-sigterm.sh`, `probe-errexit-trap.sh`). A low-risk mitigation would be `SuccessExitStatus=143` on `aos-unit.service`. | Pre-existing, rare; report only | journal 54082.57; `phase2-S2.7-phase2-*` T2.5c, journal 10:08:14.657 |
| F-3 | Stopping the manager before guests have booted makes every node hit `TimeoutStopSec=60s` (ACPI ignored) and fire `OnFailure`. Expected; `57f2627` tags it "(during manager stop)". | Behaviour, documented | `phase3-S3.3-*` pre-test teardown |
| F-4 | With the DNS port already taken, the manager start succeeds and stays active while dnsmasq crash-loops (`Type=simple`, so the post-restart `is-active` check sees it as started). Same shape as the transient unit on main. | Pre-existing, report only | `phase2-S2.5-*` T2.5c |
| F-5 | dnsmasq logs "duplicate dhcp-host IP address" while node `ExecStopPost` rewrites the hosts file during teardown. Not investigated. | Observation | `probe-stop-journal.sh` output |
