# Voice Notes

A watch app that records voice notes and uploads them to a server you run, which transcribes
them and lists them on a web page. Beta listing only, fēnix 9 Pro 51 mm only (it needs the
microphone and LTE APIs of Connect IQ 6.0.3, SDK 9.3).

## Controls

| Button | Does |
| --- | --- |
| START | Start recording; again to stop and save |
| BACK | While recording: stop and save. Otherwise: leave the app |
| MENU (hold UP) | Upload now, or delete the notes still waiting |

The screen shows the elapsed time while recording, otherwise how many notes wait and the last
upload result (`bg:` marks one from the background service).

## Settings (Connect IQ app on the phone)

| Setting | Default | Meaning |
| --- | --- | --- |
| Upload URL | empty | The server's `.../api/notes` URL |
| Upload token | empty | Bearer token the server expects |
| Upload over LTE | on | When no phone is connected, switch on LTE for the upload |
| Upload piece size | 16 KB | Size of each upload request and Storage value (1–32) |
| Longest note | 10 min | Recording stops by itself after this |

## How a note travels

1. `Recorder` captures Ogg Opus, 16 kHz mono, with Garmin's noise filter when the watch has it,
   and writes the stream to `Application.Storage` in pieces of the piece size while recording.
   The recording in progress is stored too (`cur`), so a note survives the app being closed.
2. On stop the note joins the queue (`Queue`) and `Uploader` starts: through the phone when one
   is connected, else LTE (`Communications.enableConnection`) when the setting allows it.
3. Each piece is one `POST <url>/<id>/parts/<n>?total=&recorded=&duration=`. The server answers
   `{"complete": true}` once it holds every piece; only then is the note deleted from the watch.
   A failed request leaves the note, and every request is safe to repeat.
4. While notes wait, a background service (`UploadService`) retries every 15 minutes and after
   each recorded activity, without opening the app.

The server side is a small service with this API, kept in a separate repository; any server that
implements the endpoint above works.

## Testing in the simulator

Debug builds (`just build`, `just dev voice-notes`) add two buttons the beta leaves out: DOWN queues
a 40 KB test note (zeros after an `OggS` header, since the VM has no microphone), UP uploads it
forcing the LTE route. Point the app at a server by putting its URL and token into the VM's copy of
`resources/settings/properties.xml`, never into the repo. In the simulator the phone counts as
connected; forced LTE reports status 2 (unavailable). START records silence when the simulator's
microphone access is declined, which still exercises the whole path.

## Open questions

Whether `makeWebRequest` really goes over LTE without a phone, and whether a background service
may enable LTE, is unconfirmed (Garmin's docs name only Wi-Fi and the phone). If it does not, notes
wait on the watch and upload once the phone is back. The status line shows what happened.
