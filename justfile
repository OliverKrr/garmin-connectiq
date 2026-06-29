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

# Set the app version (semver), e.g. `just bump 0.2.0`
bump VERSION:
    python3 -c "import re; p='apps/run-field/manifest.xml'; s=open(p).read(); s=re.sub(r'(<iq:application[^>]* version=\")[0-9.]+(\")', r'\g<1>{{VERSION}}\g<2>', s); open(p,'w').write(s)"
    @grep -oE '<iq:application[^>]* version="[0-9.]+"' apps/run-field/manifest.xml
