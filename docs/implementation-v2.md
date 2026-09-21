# VDM 2 implementation record

Target: Windows 10/11 x64, Flutter desktop, embedded yt-dlp / aria2 / FFmpeg / Deno.

The existing Python applications and Releases directory remain intact. The new
application is built in desktop/, with a separate Manifest V3 browser extension.

Implementation order:
1. Reproducible local SDK and engine setup, Flutter shell and persistence.
2. Native process supervision, video/file/BitTorrent task lifecycle.
3. Industrial glass UI, cookies, schedules, tray, browser handoff.
4. Analysis, unit/widget/integration checks, release packaging and documentation.

Acceptance results are recorded in docs/verification-v2.md. Do not treat an
unexecuted check, fixture, or upstream site limitation as a successful live test.
