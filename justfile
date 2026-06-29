# garmin-connectiq build/dev recipes
set shell := ["bash", "-uc"]

# Active SDK dir (override with CIQ_SDK_HOME); falls back to the SDK Manager's current-sdk.cfg
ciq_cfg := env_var_or_default("CIQ_SDK_HOME", `cat "$HOME/Library/Application Support/Garmin/ConnectIQ/current-sdk.cfg" 2>/dev/null || true`)
sdk_bin := ciq_cfg / "bin"
devices := env_var_or_default("CIQ_DEVICES_DIR", `echo "$HOME/Library/Application Support/Garmin/ConnectIQ/Devices"`)
device  := env_var_or_default("CIQ_DEVICE", "enduro3")
key     := "developer_key.der"
jungle  := "apps/run-field/monkey.jungle"
out     := "bin/run-field.prg"

# List recipes
default:
    @just --list

# Check that the toolchain is ready
doctor:
    @echo "SDK dir : {{ciq_cfg}}"
    @test -x "{{sdk_bin}}/monkeyc" && echo "monkeyc: ok" || { echo "monkeyc: MISSING — install the Connect IQ SDK"; exit 1; }
    @test -d "{{devices}}/{{device}}" && echo "device {{device}}: installed" || echo "device {{device}}: NOT installed — download it in the SDK Manager"
    @test -f {{key}} && echo "developer key: ok" || echo "developer key: missing — run 'just key'"

# Generate a developer signing key (one-time, gitignored)
key:
    @if [ -f {{key}} ]; then echo "{{key}} already exists"; else \
        openssl genrsa -out developer_key.pem 4096 && \
        openssl pkcs8 -topk8 -inform PEM -outform DER -in developer_key.pem -out {{key}} -nocrypt && \
        echo "generated {{key}}"; fi

# Compile the data field to a .prg for the target device
build:
    mkdir -p bin
    "{{sdk_bin}}/monkeyc" -d {{device}} -f {{jungle}} -o {{out}} -y {{key}} -w

# Launch the Connect IQ simulator (GUI)
sim:
    "{{sdk_bin}}/connectiq" &

# Build, then push to the running simulator
run: build
    "{{sdk_bin}}/monkeydo" {{out}} {{device}}

# Build with unit tests and run them in the simulator (launch it first with `just sim`)
# Note: monkeydo -t always exits 1; we grep the output for PASSED to set the real exit code.
test:
    mkdir -p bin
    "{{sdk_bin}}/monkeyc" -d {{device}} -f {{jungle}} -o bin/run-field-test.prg -y {{key}} --unit-test -w
    "{{sdk_bin}}/monkeydo" bin/run-field-test.prg {{device}} -t | tee /dev/stderr | grep -q "^PASSED"

# Copy the built .prg to a USB-mounted watch (override WATCH=/Volumes/GARMIN)
sideload watch="/Volumes/GARMIN": build
    test -d "{{watch}}/GARMIN/APPS" || { echo "No GARMIN/APPS at {{watch}} — see README (MTP/Android File Transfer)"; exit 1; }
    cp {{out}} "{{watch}}/GARMIN/APPS/"
    @echo "Copied to {{watch}}/GARMIN/APPS/ — eject and restart the watch"

# Remove build output
clean:
    rm -rf bin

# Build the signed PUBLIC Store package -> bin/run-field.iq
package:
    mkdir -p bin
    "{{sdk_bin}}/monkeyc" -e -r -o bin/run-field.iq -f {{jungle}} -y {{key}}
    @echo "Public .iq  -> bin/run-field.iq"

# Build the signed BETA Store package (separate app id + name) -> bin/run-field-beta.iq
package-beta:
    mkdir -p bin
    python3 -c "s=open('apps/run-field/manifest.xml').read(); s=s.replace('024f8072155f4e17a0d6fed0b18d682e','2aa9eff51b0642519e6214de6db52342').replace('name=\"@Strings.AppName\"','name=\"@Strings.AppNameBeta\"'); open('apps/run-field/manifest-beta.xml','w').write(s)"
    "{{sdk_bin}}/monkeyc" -e -r -o bin/run-field-beta.iq -f apps/run-field/monkey-beta.jungle -y {{key}}
    @echo "Beta .iq    -> bin/run-field-beta.iq"

# Set the app version (semver), e.g. `just bump 0.2.0`
bump VERSION:
    python3 -c "import re; p='apps/run-field/manifest.xml'; s=open(p).read(); s=re.sub(r'(<iq:application[^>]* version=\")[0-9.]+(\")', r'\g<1>{{VERSION}}\g<2>', s); open(p,'w').write(s)"
    @grep -oE '<iq:application[^>]* version="[0-9.]+"' apps/run-field/manifest.xml

# Prepare the manual Store upload: print version, CHANGELOG notes, checklist, dashboard URL.
# Does NOT upload or open a browser — publishing is a manual, outward-facing step.
publish-assist:
    @echo "=== Connect IQ Store upload (MANUAL) ==="
    @grep -oE 'iq:application[^>]* version="[0-9.]+"' apps/run-field/manifest.xml | grep -oE 'version="[0-9.]+"'
    @echo "--- What's New (top CHANGELOG entry) ---"
    @awk '/^## \[[0-9]/{c++} c==1 && !/^## \[/{print} c==2{exit}' CHANGELOG.md
    @echo "--- Checklist ---"
    @echo "Public : upload bin/run-field.iq       -> visibility PUBLIC"
    @echo "Beta   : upload bin/run-field-beta.iq  -> visibility PRIVATE/unlisted"
    @echo "Then   : paste What's New, add screenshots, submit (manual)."
    @echo "Upload here (open in a browser): https://apps.garmin.com/en-US/developer/dashboard"

# Bump + package a release, then remind to finish manually. e.g. `just release 0.2.0`
release VERSION: (bump VERSION) package
    @echo "Edit CHANGELOG.md for {{VERSION}}, then run: just publish-assist"
