# kDownloader

A simple macOS app for downloading videos from YouTube and the
[other sites supported by yt-dlp](https://github.com/yt-dlp/yt-dlp/blob/master/supportedsites.md).
Paste a link, check the format, press Download, and get a file that plays in
QuickTime.

- macOS 14 or later, Apple Silicon only.
- English and Russian.
- Everything it needs is inside the app: yt-dlp, FFmpeg and Deno are bundled,
  nothing has to be installed with Homebrew.

Building the app or working on its code: see [DEVELOPMENT.md](DEVELOPMENT.md).

## Installing

1. Download `kDownloader-<version>.zip` from the
   [latest release](https://github.com/kozian/kDownloader/releases/latest).
2. Unzip it and move `kDownloader.app` to `/Applications`.
3. The app is not notarized by Apple, so macOS blocks its first launch. Remove the
   quarantine flag in Terminal:

   ```sh
   xattr -dr com.apple.quarantine /Applications/kDownloader.app
   ```

   Or try to open the app once, then click **Open Anyway** in
   **System Settings → Privacy & Security**.

To update the app, replace it with the new version the same way.

## Downloading a video

1. **Paste a link** into the field at the top. A valid link starts the analysis
   at once; if you type the link instead, press Return or **Analyze**.
2. **Check the preview**: thumbnail, title, channel and duration.
3. **Choose the format** in the **Video** and **Audio** menus, or keep the
   defaults: the best quality that plays on any Mac, with the video's original
   audio track.
4. **Check the destination**: the folder (Downloads by default; click it to
   choose another one, it is remembered), the file type and the estimated size.
5. Press **Download**. The window shows the stage (video, audio, processing),
   progress, speed and remaining time. **Cancel** stops the download and returns
   to the format choice.
6. When it finishes, **Show in Finder** reveals the file. A notification is shown
   too; clicking it also opens Finder.

The file is named after the video title. An existing file is never overwritten:
a new one gets ` (2)`, ` (3)` and so on.

Only single videos are supported. A link to a video inside a playlist downloads
just that video; links to whole playlists, channels and live streams are not
supported.

## Choosing a format

### Video menu

- **Best compatible (1080p)** is the default: the highest resolution that plays
  everywhere on a Mac.
- Below it, every resolution of the same compatible format, with its codec and
  estimated size, for example "720p · H.264 · mp4 · 82 MB". Lower resolutions
  give smaller files.
- **No video (audio only)**, the last item, saves only the sound as an `.m4a`
  file (AAC), which plays in Music, QuickTime and on any Apple device.

### Audio menu

One entry per language. The track the video was recorded in is marked
**Original (English)**, or just **Original** when the site does not say its
language, and is selected by default. Dubbed tracks are listed by their
language.

### Why the formats differ

Sites store the same video in several codecs. Which one you get decides where
the file plays:

| Video | Audio | Saved as | Plays on a Mac |
|---|---|---|---|
| H.264 or HEVC | AAC | `.mp4` | Everywhere: QuickTime, Finder preview, Photos, iPhone and iPad. **Best compatibility.** |
| AV1 | AAC | `.mp4` | In QuickTime only on a Mac with M3 or later, which decodes AV1 in hardware. |
| VP9, or any video with Opus audio | | `.mkv` | Needs a third-party player such as [IINA](https://iina.io) or [VLC](https://www.videolan.org/vlc/). QuickTime does not open MKV. |

By default kDownloader offers only the first row, so whatever you download just
works. The video is never re-encoded, so there is no quality loss.

Sites often keep their highest resolutions only in VP9 or AV1. On YouTube, for
example, 4K is usually available only that way, so **Best compatible** may top
out at 1080p or 1440p while the video exists in 4K.

### Show all formats

To get every format the site offers, turn on **Show all formats** in
**kDownloader → Settings…** (⌘,).

- The **Video** menu groups the formats by codec and file type, for example
  "H.264 · MP4", "VP9 · MKV", "AV1 · MP4", with one entry per resolution and its
  estimated size. The best-compatibility group comes first. The headers of the
  other groups say what playback needs: "⚠︎ needs a third-party player" or
  "⚠︎ needs a Mac with M3 or later".
- The **Audio** menu lists every audio track by codec, with bitrate and size, and
  also offers **No audio**. If the chosen video already contains sound, the
  Audio menu is turned off and that sound is used.
- When a choice lowers compatibility, an orange ⚠ icon appears next to that
  menu; hover over it to see why.

Some videos have no compatible format at all. kDownloader then says so under the
menus, and **Show all formats** is the way to download them.

## Videos that need signing in

Age-restricted, private and members-only videos need you to be signed in to the
site. kDownloader always tries without your account first. If the site refuses,
it retries once with the cookies of a browser where you are signed in.

- The first time, it asks which browser to use. Choose one, or **Don't Use**.
  You can change the choice later in **Settings → Cookies from browser**.
- Supported: Safari, Google Chrome, Firefox, Brave, Microsoft Edge, Chromium,
  Opera and Vivaldi.
- **Safari** keeps its cookies in a protected place: give kDownloader **Full Disk
  Access** in **System Settings → Privacy & Security → Full Disk Access**. The
  error message has a button that opens that page.
- Cookies are read only while the video is being analyzed or downloaded. They
  are never stored, copied or written to the log.

## Updating yt-dlp

Sites change often, and yt-dlp, the tool that does the downloading, is updated
just as often. When a site stops working, a newer yt-dlp usually fixes it.

- Once a day kDownloader checks quietly whether a new yt-dlp is out. It never
  installs anything by itself.
- When one is available, an update icon appears next to the **Analyze** button.
  Hover over it to see the version; click it to open Settings.
- In **Settings → yt-dlp**, press **Install**. The update is downloaded, checked
  against the checksums published by yt-dlp, tested, and used right away.
  **Check for Updates** checks immediately.
- If a new version causes problems, **Use Bundled Version** goes back to the
  yt-dlp that came with the app.

FFmpeg and Deno are updated with new versions of kDownloader itself.

## When something goes wrong

Every error is shown with a short explanation and what to do, for example "Site
not supported", "Video unavailable or removed", "Not available in your region",
"No network connection" or "Not enough disk space". **Details** shows the
original message of yt-dlp, and **Retry** tries again.

- **The log** (**Window → Log**, or **Open Log** on an error) shows what the app
  did and what the tools answered. **Export…** saves it as a text file to send
  to whoever helps you. Logs of the last 10 launches are kept in
  `~/Library/Logs/kDownloader/`.
- **Partial files.** After a cancelled or failed download, unfinished files
  (`.part` and separate video and audio files) stay in the destination folder;
  kDownloader does not delete them. You can remove them by hand.
- **"The app is damaged — please reinstall it"** means a bundled tool is missing
  or does not run. Download the app again.

## About and licenses

**kDownloader → About kDownloader** shows the app version and the versions of
the bundled tools, and marks yt-dlp "updated" when an installed update is in use.

kDownloader's own code is released under the [MIT license](LICENSE). The app
bundles third-party tools under their own licenses:

| Component | License | Notes |
|---|---|---|
| [yt-dlp](https://github.com/yt-dlp/yt-dlp) | Unlicense | Its build includes Python, OpenSSL, mutagen (GPL-2.0+) and other components; their licenses and the maintainers' offer of their source are in its `THIRD_PARTY_LICENSES.txt`. |
| [FFmpeg](https://ffmpeg.org) (ffmpeg, ffprobe) | LGPL-2.1+ | Built from the official source without GPL or non-free parts. The source is attached to every release as `ffmpeg-<version>.tar.xz`. |
| [Deno](https://deno.com) | MIT | Deno embeds V8 (BSD-3-Clause) and Rust crates (mostly MIT / Apache-2.0); Deno does not publish their notices together, so only Deno's own license is included. |

The license texts are inside the app: **About → Show Licenses in Finder**.
kDownloader runs these tools as separate programs; they are not linked into its
code, so their licenses do not extend to it.

Downloading may be restricted by a site's terms of use or by copyright. Download
only what you have the right to.
