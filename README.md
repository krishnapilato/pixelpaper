# PixelPaper

> **"I tuoi dati restano con te."** — *Your data stays with you.*

A document scanner and PDF archive for Android. Everything stays on the device:
no account, no cloud, no permission beyond the camera.

The interface is **Italian only** — a product decision, not an oversight; see
[Design decisions](#design-decisions).

**Author:** Khova Krishna Pilato ·
[GitHub](https://github.com/krishnapilato) ·
[LinkedIn](https://www.linkedin.com/in/khovakrishnapilato/) ·
[krishnak.pilato@gmail.com](mailto:krishnak.pilato@gmail.com)

<sub>From an idea by Stefano Pilato.</sub>

---

<table>
  <tr>
    <td align="center" width="25%">
      <img src="web/screenshots/01-avvio.jpg" width="190" alt="Launch screen"><br>
      <sub><b>Launch</b><br>The icon is scanned, the beam writes the name</sub>
    </td>
    <td align="center" width="25%">
      <img src="web/screenshots/02-archivio.jpg" width="190" alt="Document archive"><br>
      <sub><b>Archive</b><br>Pages, size, date, folders</sub>
    </td>
    <td align="center" width="25%">
      <img src="web/screenshots/03-nome-pdf.jpg" width="190" alt="Naming the document"><br>
      <sub><b>Naming</b><br>Asked after the scan</sub>
    </td>
    <td align="center" width="25%">
      <img src="web/screenshots/04-visualizzatore.jpg" width="190" alt="Document viewer"><br>
      <sub><b>Viewer</b><br>Pages scroll vertically</sub>
    </td>
  </tr>
  <tr>
    <td align="center">
      <img src="web/screenshots/05-editor.jpg" width="190" alt="Page editor"><br>
      <sub><b>Page editor</b><br>Drag the filmstrip to reorder</sub>
    </td>
    <td align="center">
      <img src="web/screenshots/06-galleria.jpg" width="190" alt="Gallery"><br>
      <sub><b>Gallery</b><br>Full-resolution shots</sub>
    </td>
    <td align="center">
      <img src="web/screenshots/07-schermo-intero.jpg" width="190" alt="Full-screen photo"><br>
      <sub><b>Full screen</b><br>Details, text, edit, share</sub>
    </td>
    <td align="center">
      <img src="web/screenshots/08-impostazioni.jpg" width="190" alt="Settings"><br>
      <sub><b>Settings</b><br>Storage, bin, export folder, licences</sub>
    </td>
  </tr>
</table>

<sub>Screenshots taken on an Android emulator, release build. The camera and
scanner ones show the emulator's virtual scene.</sub>

---

## What it does

| Module | What you get |
| :--- | :--- |
| **Two tabs, one button** | Archivio and Galleria side by side: tap the bar or swipe between them. One action button follows the finger — scan in the Archivio, camera in the Galleria, and in the Galleria a **2-second hold imports** photos already on the phone. |
| **Smart scanner** | Google's ML Kit flow: edge detection, perspective correction, shadow cleanup, several pages in a row. You only pick the name. |
| **Manual camera** | Built on [`manual_camera_pro`](packages/manual_camera_pro). Automatic by default; exposure compensation, ISO, shutter speed, white balance and focus on stepped dials, each offering only what the lens reports. Pinch or 1×/2×/5× zoom, self-timer, torch, grid, front/back lens. The camera **stays open** between shots: every photo is confirmed on the viewfinder and lands in the folder you had open. |
| **Gallery** | Full-resolution photos, two to four columns. Select them **in the order you want the pages**: each tile shows its number, and "Crea album" copies them into a document in exactly that order. |
| **Full-screen photo** | Zoom, swipe between shots, and four actions: details, text extraction (ML Kit, with copy and share), image editing and sharing. Swipe up or down to leave. |
| **Archive** | List or grid with thumbnail, page count, size and date. Search, sorting, rename, share, **export**, print, details. A document made from photos is an **album** of page images; the PDF is built when you share, print or export it. |
| **Export** | "Esporta" opens the system save dialog, or writes straight into a folder you chose once in Impostazioni. |
| **Viewer** | Pages scroll vertically, one per screen, each with its own zoom. |
| **Page editor** | The whole page on screen, a filmstrip above the dock for drag-and-drop reordering, and four actions: add (from the app's camera or the phone's photos; PDFs also take a blank page), edit the page as an image, duplicate, delete. |
| **Folders** | One level of folders for documents and for images, moved by dragging or from the "Sposta in" (move to) menu. The folder rail stays pinned while you scroll. |
| **Bin** | Deletion is reversible for 30 days, with immediate undo; deleting for good removes the files from storage. |
| **Guide and licences** | A seven-step in-app tutorial with code-drawn illustrations and three practical tips per step, plus the full list of technologies used with their open-source licences. |
| **Launch** | A little over three seconds: the launcher mark is scanned and turns into pixels, the beam writes the name, and the finished mark rests on screen while the archive and gallery load underneath. One tap skips it. |

---

## Design decisions

Every detail answers a concrete problem:

- **Dark theme only.** The app is used on paper under a lamp; a bright UI at
  night was the flaw that started the redesign. No switch to get wrong: depth
  comes from M3 tonal layers (`surfaceContainer*`), not from shadows.
- **Italian only.** Every string lives in `assets/lang.json`; no copy is written
  in the code. The parts Flutter draws itself (text selection menu, licence
  page) and the image editor, which ships in English, are translated too: an
  English screen inside an all-Italian app is the crack you notice most.
- **The name is asked after the scan**, not before: until you have scanned,
  you do not yet know what you are saving.
- **One action button, two gestures.** Its meaning follows the tab: Archive →
  scan, Gallery → camera. Importing is the occasional action, so it sits
  behind a deliberate **2-second hold** in the Gallery: the button fills from
  the bottom, ticks once at the halfway mark and opens the photo picker at the
  end; letting go early does nothing and explains the gesture. The empty
  Gallery spells both actions out, and screen readers get import as the
  button's long-press action.
- **Tabs are pages.** Archive and Gallery are peers, so moving between them is
  a horizontal swipe as well as a tap on the bar, and the button's icon turns
  from scan to camera with the finger. Swiping is off while items are
  selected or dragged, so a selection can never be carried off screen.
- **Selection order is page order.** Picking photos for an album numbers
  them 1, 2, 3 on the tiles; the album copies them in that order. The grid's
  order is how the photos were taken, not how the document should read.
- **A document is its pages.** An album is a row and an ordered list of image
  files: creating one is a file copy, reordering is a column of integers, and
  reading shows the images at the size they are drawn. The PDF is built once,
  on the way out — share, print, export — and thrown away after.
- **The camera's dials are the lens's own.** Every stop on every dial comes from
  what Camera2 reports for that lens — ISO range, exposure range, closest
  focus, white balance presets, compensation steps. A dial the lens cannot
  turn stays in its place, dimmed, and says why when tapped, so switching
  lenses never makes the controls jump around.
- **The camera stays open.** A roll of pages is shot without leaving the
  viewfinder; each shot is confirmed on screen and filed into the folder that
  was open. The confirmation sits at the top: the bottom belongs to the
  shutter.
- **Motion follows Material.** Container transform from the button to the
  camera, shared axis for forward navigation, fade through between top-level
  destinations, emphasized easing and the M3 duration tokens everywhere.
  Lists cascade in when they appear or change folder, new items enter on their
  own, images fade in when decoded, and the splash starts exactly where
  Android's system splash leaves off. With Android's animations turned off the
  splash is skipped.
- **Long press = select and drag.** Lift without moving and you are simply in
  selection mode; keep moving and you carry the whole selection. One gesture,
  two outcomes, as in Files and Photos.
- **The bin only appears while dragging**, in place of the navigation bar: the
  target is where the thumb already is, and it cannot be hit by accident.
- **Deleting asks nothing** (it is reversible, with undo in the snackbar);
  emptying the bin does ask, because that step does not come back.
- **Folders are flat.** A scan archive needs "Fatture", "Università",
  "Ricette" — a tree would add breadcrumbs and navigation without adding value.
  Deleting a folder does not delete the files.
- **The viewer scrolls down, one page per screen**: a scan is a set of
  discrete pages, so the page number is exact and every page keeps its own
  zoom.
- **The folder rail stays pinned.** A filter that disappears as soon as you
  scroll is a filter you forget you turned on; it is also the drop target, so
  dragging no longer means scrolling back to the top.
- **A vertical swipe closes the full-screen photo.** The photo follows the
  finger and shrinks: the gesture shows where it is going before it commits,
  and if you stop halfway it springs back.
- **"Svuota la cache" lights up by itself.** Above 20 MB the row turns tonal and
  explains that space can be freed: it asks for attention only when it has
  something to give back.
- **The icon is the app's name.** An A4 sheet whose corner comes away as pixels:
  paper turning into an image. It is a vector (adaptive and monochrome icon),
  the system launch screen from Android 12, and the first frame of the
  in-app splash.

---

## Performance and memory

- **Rebuilds are scoped.** A tap in a selection repaints that tile and the
  contextual bar, not the grid: each tile watches only its own slice of the
  selection (`select`), and the drag wrapper keeps the drag payload current
  without rebuilding the tile inside it.
- **Images decoded at the size they are drawn** (`cacheWidth`), with the image
  cache capped at 80 MB: hundreds of 12 MP photos stay inside the heap. Album
  pages are shown as images, never rasterised back from a PDF.
- **No PDF until it is needed.** Albums are file copies; the PDF is composed in
  an isolate only when it leaves the app.
- **The camera holds the sensor only while it is on screen**: it is released
  when the app goes to the background and reopened on return, and native
  open/close calls are serialised so a quick lens switch cannot leak a session.
  Zoom gestures send the latest value to the camera, never a queue.
- **Lazy rendering for PDFs** through PDFium (`pdfrx`), with a bounded DPI: an
  outsized page cannot allocate hundreds of MB.
- **Housekeeping at start-up**: expired bin items, the preview cache above its
  budget, and whatever the photo picker and the camera left in the cache.
- **Minimum permissions**: `CAMERA` only. `RECORD_AUDIO`,
  `READ_EXTERNAL_STORAGE`, `INTERNET` and `ACCESS_NETWORK_STATE`, which would
  arrive from plugins, are stripped from the manifest with
  `tools:node="remove"`.

---

## Architecture

Clean Architecture, feature-first:

```text
lib/
├── main.dart                 # bootstrap: edge-to-edge, locale, image cache, error guards
├── app.dart                  # MaterialApp.router + theme + start-up housekeeping
├── core/                     # theme and motion tokens, router, strings, shared widgets
├── data/
│   ├── models/               # ScannedDocument, DocumentPage, Capture, Folder
│   ├── local/                # sqflite: database (idempotent migrations) and DAOs
│   ├── services/             # ML Kit scanner, PDF, OCR, file system, settings
│   ├── repositories/         # documents and albums, images, folders + bin
│   └── providers.dart        # composition root
└── features/
    ├── shell/ documents/ gallery/ camera/ scanner/
    ├── viewer/ editor/ folders/ trash/
    └── settings/ tutorial/ splash/
packages/
└── manual_camera_pro/        # the camera plugin, vendored with patches
```

Every feature has `application/` (Riverpod controllers) and `presentation/`
(screens and widgets). The sqflite database is the source of truth for
metadata, the file system is the source of truth for what actually exists:
every read reconciles the two.

### The camera plugin

The camera is [`manual_camera_pro`](https://pub.dev/packages/manual_camera_pro),
whose last release (0.1.0, May 2023) no longer builds with current Flutter,
Gradle 9 or AGP 8+. `pubspec.yaml` depends on it as usual and overrides it with
a local copy in `packages/manual_camera_pro`, patched to build (namespace,
modern Gradle, no v1 embedding) and to work: the still capture now applies the
manual settings (0.1.0 only applied them to the preview), `focusDistance: 0`
really means autofocus, `dispose()` survives a failed `initialize()`, and the
settings, exposure compensation and zoom can change on a running session.
Every change is listed in
[its CHANGELOG](packages/manual_camera_pro/CHANGELOG.md) and marked
"PixelPaper patch" in the source.

---

## Stack

| Area | Packages |
| :--- | :--- |
| State | `flutter_riverpod` 3 (no code generation) |
| Navigation | `go_router` 18 (every route declares its own transition), `animations` (Material motion) |
| Language | `flutter_localizations` (locale fixed to `it`) + `assets/lang.json` |
| Database | `sqflite` (schema v4, idempotent migrations) |
| Capture | `google_mlkit_document_scanner`, `manual_camera_pro` (vendored), `permission_handler`, `image_picker` |
| PDF | `pdf`, `printing`, `syncfusion_flutter_pdf`, `pdfrx` |
| Images | `pro_image_editor`, `google_mlkit_text_recognition` |
| Export | `flutter_file_dialog`, `saf_util`, `saf_stream` |
| Misc | `share_plus`, `url_launcher`, `intl`, `crypto`, `package_info_plus` |

---

## Build requirements

| | Version |
| :--- | :--- |
| Flutter / Dart | 3.47.5 / 3.13.4 |
| Gradle | 9.1.0 |
| Android Gradle Plugin | 9.0.1 |
| Kotlin | 2.3.20 (AGP's built-in Kotlin) |
| JDK | 17 (`sourceCompatibility`/`jvmTarget`), built on JDK 21 |
| compileSdk / targetSdk / minSdk | 36 / 36 / 24 |

`compileSdk 36` is required by `google_mlkit_document_scanner` 0.6.x; it is also
why `permission_handler` stays on 12.x (13.x needs 37). The scanner only works
on Android devices with Google Play services: without them the app says so and
offers the manual camera instead.

```bash
flutter pub get
flutter run                 # debug on the connected device
flutter test                # camera scales and labels, the action button, page order
flutter build apk --release # without key.properties it signs with the debug key
```

`flutter analyze` reports no issues.

### Two things a release build can break silently

Both were found by testing the release APK on a device, and neither shows up in
debug — test the release build before every upload.

- **R8 and ML Kit.** ML Kit and Play Services resolve implementations *by name*
  at runtime, so R8 renaming them makes the lookup return null: the scanner and
  text extraction die with a `NullPointerException` thrown from inside
  `Objects.requireNonNull`, far from the cause. `proguard-rules.pro` keeps
  `com.google.mlkit.**`, `com.google.android.gms.**` and the plugins' bridge
  classes, plus the annotation and signature attributes those libraries read
  back.
- **`uses-feature` and the manifest merger.** The merger ORs `required` across
  every library that declares a feature, so a single plugin declaring
  `android.hardware.camera.any` as required ships the app as "camera
  required" and Play drops every camera-less device. The manifest declares
  camera, camera.any and camera.autofocus as not required with
  `tools:replace="android:required"`. Check the merged result, not the source:

  ```bash
  grep -A2 uses-feature build/app/intermediates/merged_manifests/release/processReleaseManifest/AndroidManifest.xml
  ```

---

## Publishing to Google Play

1. **Create the signing key** (once, and keep it: without it you can never
   publish an update again).

   ```bash
   keytool -genkey -v -keystore pixelpaper.jks -keyalg RSA -keysize 2048 -validity 10000 -alias pixelpaper
   ```

2. **Declare it in `android/key.properties`** — the file is in `.gitignore`
   along with `*.jks`, so the key and its passwords never reach GitHub:

   ```properties
   storeFile=C:/absolute/path/pixelpaper.jks
   storePassword=…
   keyAlias=pixelpaper
   keyPassword=…
   ```

3. **Build the bundle** you upload to the Play Console:

   ```bash
   flutter build appbundle --release
   ```

   The artefact lands in `build/app/outputs/bundle/release/app-release.aab`.
   Without `key.properties` the bundle build **fails on purpose**: a
   debug-signed bundle installs and builds fine and is rejected only at the end
   of the upload ("signed with the wrong key"), so it is better refused here.
   A release *APK* still falls back to the debug key, because a locally signed
   APK is genuinely useful.

   Check what you are about to upload before you upload it:

   ```bash
   keytool -printcert -jarfile build/app/outputs/bundle/release/app-release.aab
   ```

   The SHA1 must match the upload certificate Play shows under
   *Release → Setup → App signing*.

   > `key.properties` is untracked, so a **git worktree does not inherit it**.
   > Build from the main checkout, or copy the file into the worktree's
   > `android/` first.

4. **Version number**: the `version:` line in `pubspec.yaml`, in the form
   `<versionName>+<versionCode>`. The number after the `+` is the
   `versionCode` and must be higher than every code already uploaded, or Play
   rejects the bundle before it looks at anything else.

The `applicationId` is `com.khovakrishnapilato.pixelpaper`. The bundle carries
every ABI: the actual per-device download is a fraction of its size.

---

## Editing the guide

The user guide at
[krishnapilato.github.io/pixelpaper](https://krishnapilato.github.io/pixelpaper/)
lives in `web/`: `index.html`, `styles.css`, `favicon.svg`. Plain HTML and CSS,
no framework, no build step — which is the point: a page you can fix in thirty
seconds is a page that stays accurate. The stylesheet runs on one spacing
scale (multiples of 4 px) and one reading column, so text, tables and boxes
always share the same right edge.

Editing it is a commit. `.github/workflows/deploy.yml` watches `web/**` on
`main` and publishes the folder as it is, so a change is live about half a
minute after it lands — from your editor or straight from GitHub's web editor,
without touching anything else in the repository. `workflow_dispatch` re-runs
the deploy by hand when you need it.

```bash
# preview before pushing, exactly as Pages serves it
node tool/serve-web.js      # then open http://localhost:4173
```

Two things worth keeping true: paths inside the page stay **relative**
(`styles.css`, not `/styles.css`), because the site is served from
`/pixelpaper/` and an absolute path would 404; and the CSS carries the
breakpoints, so check a change at both a phone width and a desktop one before
committing.

Pages must be set to **Settings → Pages → Source: GitHub Actions** for any of
this to publish.

---

## Text recognition

Text extraction uses ML Kit's **Latin** model: it recognises a *script*, not a
language, so it reads anything printed in the Latin alphabet — Italian,
English, French, and Latin itself. Greek (ancient or modern), Cyrillic, Hebrew
and Arabic are not supported, because ML Kit only ships Latin, Chinese,
Devanagari, Japanese and Korean models.

The practical limit is the printing, not the language: modern type reads well,
while blackletter/Fraktur, incunabula, long s (ſ), scribal abbreviations and
handwriting give poor results, and macrons (ā ē) are usually dropped. That is
why the gallery keeps shots at full resolution and uncropped: OCR always works
on the sharpest original available.
