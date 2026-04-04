# MovieCompanion

An iOS app that displays synchronized subtitles while you watch a movie in the theater. It uses on-device speech recognition to detect where you are in the film and automatically syncs the subtitles to the correct moment.

This gives people who do not understand the movie's language a chance to follow the story in the theater.

## Features

- **Auto-sync** — listens briefly to the movie audio and finds the matching subtitle timestamp automatically.
- **Any display language** — choose to read subtitles in any language you have loaded; the sync button works regardless of which language you pick.
- **Dark theme** — keeps your screen dim so you do not disturb other audience members.
- **Google Drive library** — manage your subtitle files from a shared Google Drive folder; the app downloads them automatically.
- **Works offline** — once subtitles are synced to your device, no internet connection is needed in the theater.
- **Short listening window** — the microphone is only active for up to 30 seconds during a sync attempt.

## How to use

1. Open the app and set up your subtitle library (see the next section).
2. Choose the movie you want to watch from the list.
3. Choose the subtitle language you want to read.
4. When the movie starts, tap the **Play** button as the first production logo appears. The timer does not need to be perfectly accurate — you can re-sync at any time.
5. If the subtitles fall out of sync, tap the **mic button** in the bottom-right corner.
6. The mic icon will pulse to show it is listening. Wait for a moment when characters are speaking clearly. The app will find the correct position and jump to it automatically.
7. If the sync attempt fails, a dialog will appear offering you the option to try again.

## Setting up your subtitle library

### 1. Prepare a shared Google Drive folder

Create a folder in Google Drive and set its sharing permission to **Anyone with the link can view**.

### 2. Add subtitle files

MovieCompanion uses the **SRT** subtitle format. To display subtitles in your chosen language, you need at least two SRT files for the same movie:

- One in the **original spoken language of the film** (currently English is supported for audio matching).
- One in the **language you want to read**.

Name your files using this pattern:

```
MovieTitle_EN.srt
MovieTitle_ZH.srt
```

For example, for an English/Chinese pair:

```
Inception_EN.srt
Inception_ZH.srt
```

Upload both files to your shared Google Drive folder. Subtitle files for most films become available online a few weeks after release. You may need to translate an English subtitle into your preferred language using a translation tool.

### 3. Set up the auto-sync script

1. Go to [script.google.com](https://script.google.com) and create a new project.
2. Copy the contents of `scripts/MovieLibrarySync.js` (from this repository) into the script editor.
3. Replace `FOLDER_ID` in the script with the ID of your shared folder (the long string in the folder's sharing URL).
4. From the toolbar, click **Run > installTrigger** to schedule the script to run every 30 minutes — this keeps the library index up to date automatically.
5. Alternatively, run **syncManifest** manually each time you upload new subtitle files.

### 4. Connect the app to your library

In the MovieCompanion app, tap the **gear icon** on the movie list screen, paste your shared folder link, and tap Save. Your movies will appear in the list shortly.

## Planned improvements

- [ ] Detect the movie's native audio language automatically so you do not need to specify it.
- [ ] Built-in translation tool so you only need to find an English subtitle and the app handles the rest.
- [ ] App interface available in multiple languages.

---

*MovieCompanion is a personal project. Subtitles are the intellectual property of their respective rights holders — please do not distribute subtitle files publicly. The goal of this app is to help people enjoy films across language barriers.*
