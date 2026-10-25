# Voice Spike

A throwaway probe for the microphone and LTE APIs that Connect IQ SDK 9.3 (API level 6.0.3) added.
It answers the questions a voice-notes app depends on before that app is written, and is deleted
once they are answered. Sideload only, fēnix 9 Pro 51 mm only.

Open questions it settles:

1. Does `makeWebRequest` go over LTE once an app calls `Communications.enableConnection`, with no
   phone in reach? Garmin's docs only say "WiFi or a mobile device over Bluetooth".
2. How large a POST body gets through, via the phone and via LTE?
3. Is Ogg Opus at 16 kHz mono supported, and what byte rate does it produce?

## Build and install

Needs SDK 9.3 or newer and current device files from the SDK Manager.

```sh
just build voice-spike
```

Copy `bin/voice-spike.prg` to `GARMIN/APPS/` (OpenMTP on macOS). To keep the log, also create an
empty `GARMIN/APPS/LOGS/VOICESPIKE.TXT`; the watch appends every log line to it.

## Use

START opens the probe menu; results appear as log lines on screen.

| Item | Logs |
| --- | --- |
| Status | phone connected, free memory, Opus/WAV support, filter count, Wi-Fi and LTE status |
| Record 10 s | bytes, chunks, duration, byte rate, first four bytes (`OggS` = a valid Ogg start) |
| Upload rec | `POST <size> -> <code> in <ms>` for the last recording |
| Size sweep | the same for 4, 16, 64 and 128 KB bodies |
| LTE on / off | the `enableConnection` update callback: connected flag and error code |

Uploads POST to the `uploadUrl` setting (default `https://httpbin.org/status/200`, which discards
the body). Response code 200 is success. Negative codes are Connect IQ errors, listed in the
`Communications` API docs; -104 means no phone connection.

## Test protocol

LTE needs an active plan on the watch.

1. **Baseline, phone connected:** Status, Record 10 s, Upload rec, Size sweep.
2. **No phone, LTE untouched:** turn Bluetooth off on the phone, then run Status and Size sweep.
   Expected: -104 on every request.
3. **No phone, LTE on:** LTE on, wait for `LTE conn true`, then Size sweep and Upload rec.
   If 200 comes back here but not in step 2, web requests go over LTE.
4. LTE off, turn Bluetooth back on.

The answer is in the step 2 vs step 3 lines.
