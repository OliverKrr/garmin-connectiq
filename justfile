# garmin-connectiq build/dev recipes
set shell := ["bash", "-uc"]

# Active SDK dir (override with CIQ_SDK_HOME); falls back to the SDK Manager's current-sdk.cfg
ciq_cfg := env_var_or_default("CIQ_SDK_HOME", `cat "$HOME/Library/Application Support/Garmin/ConnectIQ/current-sdk.cfg" 2>/dev/null || true`)
sdk_bin := ciq_cfg / "bin"
devices := env_var_or_default("CIQ_DEVICES_DIR", `echo "$HOME/Library/Application Support/Garmin/ConnectIQ/Devices"`)
device  := env_var_or_default("CIQ_DEVICE", "fenix9pro51mm")
# Signing key: the release key the Store listings were first signed with (restore it, never
# regenerate it). CIQ_KEY points at another key, e.g. a throwaway key inside the simulator VM.
key     := env_var_or_default("CIQ_KEY", "developer_key.der")
# Store packaging/release recipes below (package, bump, tag, ...) are Run Cockpit's only;
# build/run/dev/test/sideload take the app dir name under apps/ (default run-cockpit).
jungle  := "apps/run-cockpit/monkey.jungle"

# Connect IQ Store app ids (each binds an .iq to one listing; Garmin assigns them).
# Both listings exist. A Store/dashboard URL id is NOT the app id (see RELEASE.md).
# public_app_id must match the id in apps/run-cockpit/manifest.xml — change both together.
public_app_id := "5f713bad3e2544559f1ba1cff9e59aa3"
beta_app_id   := "2aa9eff51b0642519e6214de6db52342"

# List recipes
default:
    @just --list

# Check that the toolchain is ready
doctor:
    @echo "SDK dir : {{ciq_cfg}}"
    @test -x "{{sdk_bin}}/monkeyc" && echo "monkeyc: ok" || { echo "monkeyc: MISSING — install the Connect IQ SDK"; exit 1; }
    @test -d "{{devices}}/{{device}}" && echo "device {{device}}: installed" || echo "device {{device}}: NOT installed — download it in the SDK Manager"
    @test -f {{key}} && echo "developer key: ok" || echo "developer key: missing — restore the release key from its backup (see CLAUDE.md); 'just key' only for a new app"

# Generate a new signing key for a new app or contributor (gitignored; Store updates need the existing key)
key:
    @if [ -f {{key}} ]; then echo "{{key}} already exists"; else \
        openssl genrsa -out developer_key.pem 4096 && \
        openssl pkcs8 -topk8 -inform PEM -outform DER -in developer_key.pem -out {{key}} -nocrypt && \
        echo "generated {{key}}"; fi

# Compile an app (dir under apps/, default run-cockpit) to bin/<app>.prg for the target device
build app="run-cockpit":
    mkdir -p bin
    "{{sdk_bin}}/monkeyc" -d {{device}} -f apps/{{app}}/monkey.jungle -o bin/{{app}}.prg -y {{key}} -w

# The simulator recipes (test, dev, screenshot, shoot) run in a local macOS VM, so no simulator
# window or scripted keystroke reaches this desktop (docs/simulator-vm.md). The *-local recipes
# use this Mac's own simulator instead: opt in only on a desktop nobody is working at.

# Build an app with unit tests and run them in the VM's simulator
test app="run-cockpit":
    tools/ciq-vm.sh test {{app}}

# Build an app and load it into the VM's simulator (re-run to reload); watch it with `just vm screen`
dev app="run-cockpit":
    tools/ciq-vm.sh dev {{app}}

# Load an app into the VM's simulator and save its screen to bin/vm/<app>.png
screenshot app="run-cockpit":
    tools/ciq-vm.sh screenshot {{app}}

# Store screenshot choreography in the VM, fake patches included; PNGs land in bin/vm/
shoot:
    tools/ciq-vm.sh shoot

# The VM itself, e.g. `just vm start|stop|screen|peek|ssh|check` (tools/ciq-vm.sh)
vm *args:
    tools/ciq-vm.sh {{args}}

# Launch this Mac's simulator (a GUI window on this desktop)
sim-local:
    "{{sdk_bin}}/connectiq" &

# Build an app, then push it to this Mac's running simulator
run-local app="run-cockpit": (build app)
    "{{sdk_bin}}/monkeydo" bin/{{app}}.prg {{device}}

# Build an app, launch this Mac's simulator if needed and load it; re-run to reload
dev-local app="run-cockpit": (build app)
    ps -Ao comm | grep -qiE '(^|/)simulator$' || { "{{sdk_bin}}/connectiq" & sleep 9; }
    "{{sdk_bin}}/monkeydo" bin/{{app}}.prg {{device}}

# Clear crashed/stale simulator + monkeydo instances on this Mac (they make the *-local recipes hang)
kill-local:
    pkill -f monkeydo || true
    pkill -f "ConnectIQ.app/Contents" || true
    @echo "cleared stale simulator + monkeydo instances"

# monkeydo -t always exits 1; the recipe greps the output for PASSED to set the real exit code.
# Build an app with unit tests and run them in this Mac's simulator (start it with `just sim-local`)
test-local app="run-cockpit":
    mkdir -p bin
    "{{sdk_bin}}/monkeyc" -d {{device}} -f apps/{{app}}/monkey.jungle -o bin/{{app}}-test.prg -y {{key}} --unit-test -w
    "{{sdk_bin}}/monkeydo" bin/{{app}}-test.prg {{device}} -t | tee /dev/stderr | grep -q "^PASSED"

# Generate bin/run-sim.fit test data (pace sweeps zones, HR+cadence ramp); load via Simulation -> Activity Data. Needs: pip install fit-tool
sim-fit:
    mkdir -p bin
    python3 tools/gen_sim_fit.py

# Score GapModel against Garmin's lap GAP in real FIT files (Export Original); --fit re-tunes A/B
gap-check +args:
    uv run --script tools/gap_check.py {{args}}

# Copy an app's built .prg to a USB-mounted watch, e.g. `just sideload sauna-timer`
sideload app="run-cockpit" watch="/Volumes/GARMIN": (build app)
    test -d "{{watch}}/GARMIN/APPS" || { echo "No GARMIN/APPS at {{watch}} — MTP watches (e.g. Enduro 3, fenix 9) don't mount on macOS: copy bin/{{app}}.prg with OpenMTP (see README, Sideloading on macOS)"; exit 1; }
    cp bin/{{app}}.prg "{{watch}}/GARMIN/APPS/"
    @echo "Copied to {{watch}}/GARMIN/APPS/ — eject and restart the watch"

# Remove build output
clean:
    rm -rf bin

# Regenerate Store listing images (PNG) from the SVG sources in store-assets/
store-assets:
    rsvg-convert -w 500 -h 500 store-assets/cover.svg -o store-assets/cover.png
    rsvg-convert -w 1440 -h 720 store-assets/hero.svg -o store-assets/hero.png
    @echo "store-assets/{cover,hero}.png regenerated"

# Validate Store text and refresh the copy-paste files: store-assets/description.txt and
# store-assets/whats-new-public.txt are checked as-is (authored); store-assets/whats-new.txt is
# regenerated from CHANGELOG.md's released history. All three must stay within the Store's
# 4000-char plain-ASCII limit (no < or >). Fails the build when violated.
validate-store-text:
    python3 tools/validate_store_text.py

# Build BOTH signed Store packages (Public + Beta) at the current manifest version, so
# the two listings never drift. The beta manifest is regenerated from manifest.xml each
# time (same version; only the app id + name differ), then both are compiled.
package: validate-store-text
    mkdir -p bin
    "{{sdk_bin}}/monkeyc" -e -r -o bin/run-cockpit.iq -f {{jungle}} -y {{key}}
    python3 -c "s=open('apps/run-cockpit/manifest.xml').read(); s=s.replace('{{public_app_id}}','{{beta_app_id}}').replace('name=\"@Strings.AppName\"','name=\"@Strings.AppNameBeta\"'); open('apps/run-cockpit/manifest-beta.xml','w').write(s)"
    "{{sdk_bin}}/monkeyc" -e -r -o bin/run-cockpit-beta.iq -f apps/run-cockpit/monkey-beta.jungle -y {{key}}
    @echo "Public .iq -> bin/run-cockpit.iq       (app id {{public_app_id}} — public listing)"
    @echo "Beta   .iq -> bin/run-cockpit-beta.iq  (app id {{beta_app_id}} — beta listing)"

# Set the app version (semver), e.g. `just bump 0.2.0`
bump VERSION:
    python3 -c "import re; p='apps/run-cockpit/manifest.xml'; s=open(p).read(); s=re.sub(r'(<iq:application[^>]* version=\")[0-9.]+(\")', r'\g<1>{{VERSION}}\g<2>', s); open(p,'w').write(s)"
    @grep -oE '<iq:application[^>]* version="[0-9.]+"' apps/run-cockpit/manifest.xml

# Prepare the manual Store upload: print version, CHANGELOG notes, checklist, dashboard URL.
# Does NOT upload or open a browser — publishing is a manual, outward-facing step.
publish-assist: validate-store-text
    @echo "=== Connect IQ Store upload (MANUAL) ==="
    @grep -oE 'iq:application[^>]* version="[0-9.]+"' apps/run-cockpit/manifest.xml | grep -oE 'version="[0-9.]+"'
    @echo "--- Paste files (select all + copy + paste) ---"
    @echo "Description (both) : store-assets/description.txt"
    @echo "What's New / Beta  : store-assets/whats-new.txt (regenerated from CHANGELOG.md just now)"
    @echo "What's New / Public: store-assets/whats-new-public.txt (authored, folded per milestone)"
    @echo "--- Checklist ---"
    @echo "Beta   : upload bin/run-cockpit-beta.iq  -> beta listing (private/unlisted); paste description + whats-new.txt"
    @echo "Public : upload bin/run-cockpit.iq       -> public listing; paste description + whats-new-public.txt"
    @echo "Then   : add screenshots, set keywords/category, submit (manual)."
    @echo "After  : once the upload is accepted -> just tag -> git push origin the tag"
    @echo "         public milestone only        -> just github-release <version>  (pushes tag + GitHub Release + .iq)"
    @echo "Upload here (open in a browser): https://apps-developer.garmin.com (new dashboard; old: https://apps.garmin.com/en-US/developer/dashboard)"

# Create an annotated, app-scoped git tag at the current manifest version (LOCAL only — push it
# yourself after the Store upload is accepted). The tag is the only durable link from a Store version
# to its exact source: CI cannot rebuild (Garmin MFA blocks headless SDK logins), so nothing else pins
# the shipped binary. Tag EVERY shipped version (beta and public).
tag:
    #!/usr/bin/env bash
    set -euo pipefail
    version=$(grep -oE 'iq:application[^>]* version="[0-9.]+"' apps/run-cockpit/manifest.xml | grep -oE 'version="[0-9.]+"' | grep -oE '[0-9.]+')
    tag="run-cockpit-v${version}"
    if git rev-parse -q --verify "refs/tags/${tag}" >/dev/null; then
        echo "tag ${tag} already exists — nothing to do"
        exit 0
    fi
    git tag -a "${tag}" -m "Run Cockpit ${version}"
    echo "created local tag ${tag}"
    echo "after the Store upload is accepted, push it:  git push origin ${tag}"

# Publish a GitHub Release for a PUBLIC milestone. OUTWARD-FACING: run this yourself, after the public
# Store upload is accepted. Pushes the app-scoped tag, then creates the release with that version's
# folded public note (its section of whats-new-public.txt) and the built .iq attached. Betas get no
# GitHub Release. The .iq is the Store bundle (archival) — sideloaders build a per-device .prg instead.
github-release VERSION:
    #!/usr/bin/env bash
    set -euo pipefail
    tag="run-cockpit-v{{VERSION}}"
    test -f bin/run-cockpit.iq || { echo "bin/run-cockpit.iq missing — run 'just package' first"; exit 1; }
    if ! git rev-parse -q --verify "refs/tags/${tag}" >/dev/null; then
        echo "local tag ${tag} missing — run 'just tag' first"; exit 1
    fi
    notes=$(awk -v t="Version {{VERSION}} " 'index($0,t)==1{p=1;print;next} p&&/^Version /{p=0} p{print}' store-assets/whats-new-public.txt)
    if [ -z "${notes}" ]; then
        echo "no 'Version {{VERSION}}' section in store-assets/whats-new-public.txt — add the milestone entry first"; exit 1
    fi
    git push origin "${tag}"
    printf '%s\n' "${notes}" | gh release create "${tag}" bin/run-cockpit.iq --title "Run Cockpit {{VERSION}}" --notes-file -
    echo "published GitHub Release ${tag}"

# Bump + package a release, then remind to finish manually. e.g. `just release 0.2.0`
release VERSION: (bump VERSION) package
    @echo "Next: edit CHANGELOG.md for {{VERSION}} (+ add the folded note to store-assets/whats-new-public.txt if this is a public milestone), commit, then:"
    @echo "      just publish-assist  ->  upload in the dashboard  ->  just tag  ->  git push the tag"
    @echo "      public milestone only, after the upload is accepted:  just github-release {{VERSION}}"
