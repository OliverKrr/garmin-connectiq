# Voice Notes

A watch app that records voice notes and uploads them to a server you run, which transcribes
them and lists them on a web page. Beta listing only, fēnix 9 Pro 51 mm only (it needs the
microphone and LTE APIs of Connect IQ 6.0.3, SDK 9.3).

## Controls

The app always opens on the record screen.

| Button | Record screen | On a note |
| --- | --- | --- |
| START | Start recording; again to stop and save (green check) | Play; again to stop |
| DOWN / UP | Step to the newest note / back. While recording: DOWN asks "Discard recording?", UP does nothing | Older note / newer note, then the record screen |
| BACK | While recording: asks "Discard recording?" (red X); yes deletes it, no keeps recording. Otherwise: leave the app | Back to the record screen |
| MENU (hold UP) | Upload now, delete the notes still waiting, or settings | Delete this note |

Two-button watches (Venu 4, Venu X1, Approach S72) have only START and BACK: swipe up and down
step through the notes (swipe up while recording asks to discard, like DOWN), and a long press on
the screen or a swipe left opens the menu; the screen says "hold: menu" and "swipe up: N notes".
The long press and the swipe left open the menu on every watch.

While recording, a green check by START and a red X by BACK show what each does; a tap on the
check saves, a tap on the X asks to discard, other taps do nothing. A discarded recording leaves
nothing on the watch and never uploads; leaving the app while recording still saves it.

The record screen shows the elapsed time while recording, otherwise how many notes wait, the last
upload result and how many notes are on the watch. The result names its route and keeps the error
code, e.g. `LTE: all uploaded` or `phone: upload failed (-1004, 3 tries)`; `bg:` marks one from the
background service. A playback error shows under the note with its code; one that ended the app
shows on the next start as `last playback: ...`.
A note shows its date, length, size and whether it is uploaded. The glance in the widget loop
shows how many notes wait.

## Devices

The app lists the 23 watches that have both Connect IQ's `Audio.Capture` API (SDK 9.3, API
6.0.3) and a built-in microphone; all of them also have a speaker for playback. Seven more watches
expose the API but have no microphone, so they are left out (checked 2026-11-07; Garmin publishes
no single list, so the sources are reviews and spec sheets, linked below).

| Device (SDK id) | Screen | Microphone | Source |
| --- | --- | --- | --- |
| fenix 9 / 9 Pro / 9 Pro Solar, all sizes (`fenix943mm`, `fenix947mm`, `fenix9pro43mm`, `fenix9pro47mm`, `fenix9pro51mm`, `fenix9prosolar47mm`, `fenix9prosolar51mm`) | 416-466 AMOLED; Solar 260/280 MIP | yes | [DC Rainmaker, fenix 9 review](https://www.dcrainmaker.com/2026/09/garmin-fenix9-series-pro-inreach-solar-in-depth-review.html), [the5krunner, fenix 9](https://the5krunner.com/specs/garmin/fenix-9/) |
| fenix 8 / 8 Pro / 8 Solar (`fenix843mm`, `fenix847mm`, `fenix8pro47mm`, `fenix8solar47mm`, `fenix8solar51mm`) | 416/454 AMOLED; Solar 260/280 MIP | yes | [DC Rainmaker, fenix 8 review](https://dcrainmaker.com/2024/08/garmin-fenix-8-in-depth-review.html) |
| Forerunner 970, 570 42/47 mm (`fr970`, `fr57042mm`, `fr57047mm`) | 390/454 AMOLED | yes | [Tom's Guide](https://www.tomsguide.com/wellness/fitness-trackers/garmin-announces-forerunner-570-and-970-heres-everything-you-need-to-know-about-the-new-watches) |
| Venu 4 41/45 mm, D2 Air X15 (`venu441mm`, `venu445mm`) | 390/454 AMOLED, two buttons | yes | [Garmin blog](https://www.garmin.com/en-US/blog/general/which-garmin-smartwatch-is-right-for-me/), [the5krunner, D2 Air X15](https://the5krunner.com/2025/10/22/garmin-d2-air-x15-a-buyers-guide/) |
| Venu X1 (`venux1`) | 448x486 AMOLED, rectangular, two buttons | yes | [Garmin blog](https://www.garmin.com/en-US/blog/general/which-garmin-smartwatch-is-right-for-me/) |
| MARQ Gen 3 (`marq3`) | 454 AMOLED | yes | [the5krunner, MARQ Gen 3](https://the5krunner.com/specs/garmin/marq-3/) |
| D2 Mach 2, D2 Mach 2 Pro (`d2mach2`, `d2mach2pro`) | 454 AMOLED | yes | [Garmin newsroom, Mach 2 Pro](https://www.garmin.com/en-US/newsroom/?p=6179), [Garmin manual, voice notes](https://www8.garmin.com/manuals/webhelp/GUID-EA112C95-8563-4EED-AADF-2AADFBB95646/EN-US/GUID-700E76C4-F7E2-4984-8199-D59D6A31DFB9.html) |
| Approach S72 43/47 mm (`approachs7243mm`, `approachs7247mm`) | 416/454 AMOLED, two buttons | yes | [Wareable](https://www.wareable.com/garmin/garmin-approach-s72-golf-watch-voice-calling-flashlight-swing-analysis-features-price) |
| Enduro 3 (`enduro3`) | | no | [Tom's Guide review](https://www.tomsguide.com/wellness/smartwatches/garmin-enduro-3-review) |
| Enduro 4 (`enduro4`) | | no (beeper only) | [DC Rainmaker](https://www.dcrainmaker.com/2026/10/garmin-enduro-4-vs-fenix9-vs-enduro3-detailed-comparison-review.html) |
| fenix E (`fenixe`) | | no | [Gadgets & Wearables](https://gadgetsandwearables.com/technical-specs/garmin-fenix-e) |
| Forerunner 70, 170, 170 Music (`fr70`, `fr170`, `fr170m`) | | no (170 Music: beeper only) | [DC Rainmaker, FR70 vs FR170](https://www.dcrainmaker.com/2026/05/garmin-forerunner70-vs-forerunner170-detailed-comparison-review.html) |
| vivoactive 6 (`vivoactive6`) | | no (sources conflict; TechRadar's review notes it has none) | [TechRadar review](https://www.inkl.com/news/garmin-vivoactive-6-review-a-feature-stuffed-pocket-rocket) |

`Audio.Capture` support per device comes from each device's `<id>.api.debug.xml` in the SDK's
Devices folder. All 23 build; the screen layout and the save/discard cues scale with the screen and
sit next to START (about 2 o'clock) and BACK (about 4 o'clock) on every listed watch, per the key
positions in each device's `simulator.json`; on the rectangular Venu X1 they hug the right edge.
Only the fenix 9 Pro 51 mm has been tested on a real watch.

## Settings (phone app, most also on the watch)

| Setting | Default | Meaning |
| --- | --- | --- |
| Upload URL | empty | The server's `.../api/notes` URL |
| Upload token | empty | Bearer token the server expects |
| Upload over LTE | on | When no phone is connected, switch on LTE for the upload |
| Upload piece size | 16 KB | Size of each upload request and Storage value (1–32) |
| Longest note | 10 min | Recording stops by itself after this |
| Keep uploaded notes | 7 days | Uploaded notes stay for playback this long; 0 deletes them right after upload |
| Watch space for notes | 1024 KB | Above this, the oldest uploaded notes go first |
| Retry interval | 15 min | How often the background retries waiting notes (5–60; the platform minimum is 5) |

MENU, Settings on the watch changes keep days (0, 1, 3, 7, 14, 30), watch space (256–2048 KB),
retry interval (5, 15, 30, 60 min), upload over LTE and longest note (5, 10, 20, 30 min). It writes
the same settings the phone app edits; URL, token and piece size are phone-only.

Notes that are not uploaded yet are never deleted automatically, only from MENU. Cleanup runs after
every upload and when the app starts. When the watch's storage is full, a recording stops and keeps
what it has ("watch storage full").

## How a note travels

1. `Recorder` captures Ogg Opus, 16 kHz mono, with Garmin's noise filter when the watch has it,
   and writes the stream to `Application.Storage` in pieces of the piece size while recording.
   The recording in progress is stored too (`cur`), so a note survives the app being closed.
2. On stop the note joins the queue (`Queue`) and `Uploader` starts: through the phone when one
   is connected, else LTE (`Communications.enableConnection`) when the setting allows it.
3. Each piece is one `POST <url>/<id>/parts/<n>?total=&recorded=&duration=`. The server answers
   `{"complete": true}` once it holds every piece; only then is the note deleted from the watch.
   A failed request leaves the note, and every request is safe to repeat. A dropped connection
   or a timeout (`-2`, `-3`, `-300`, `-1004`) is retried twice at once before the run gives up.
4. While notes wait, a background service (`UploadService`) retries every retryMin minutes (default 15) and after
   each recorded activity, without opening the app. It stays out while the app is open (the app
   stamps `fg` in Storage), so the two never save the note list at the same time.
5. Uploaded notes stay for playback (`Player` streams their stored pieces to the speaker) until
   `Queue.prune()` removes them under the two cleanup settings.

The server side is a small service with this API, kept in a separate repository; any server that
implements the endpoint above works.

## Testing in the simulator

Debug builds (`just build`, `just dev voice-notes`) add two MENU items the beta leaves out: "Test
note" queues a 40 KB test note (zeros after an `OggS` header, since the VM has no microphone), and
"Upload via LTE" uploads forcing the LTE route. The simulator opens apps with a glance in glance
mode; switch Settings, Glance Launch Mode to normal to reach the app. Point the app at a server by putting its URL and token into the VM's copy of
`resources/settings/properties.xml`, never into the repo. In the simulator the phone counts as
connected; forced LTE reports status 2 (unavailable). START records silence when the simulator's
microphone access is declined, which still exercises the whole path.

## Open questions

Whether `makeWebRequest` really goes over LTE without a phone, and whether a background service
may enable LTE, is unconfirmed (Garmin's docs name only Wi-Fi and the phone). If it does not, notes
wait on the watch and upload once the phone is back. The status line shows what happened.
A first test (2026-11-03, phone Bluetooth off): LTE switched on (`enableConnection` reported
connected), but the request ended in `-1004` (connection dropped) and never reached the server.
