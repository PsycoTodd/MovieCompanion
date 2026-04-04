// ─── CONFIG ────────────────────────────────────────────────────────────────
// Extract from your folder URL:
// https://drive.google.com/drive/folders/THIS_PART
const FOLDER_ID = 'THIS_PART';
const MANIFEST_FILENAME = 'manifest.json';
// ───────────────────────────────────────────────────────────────────────────

/**
 * Scans the folder for .srt files and rebuilds manifest.json if anything changed.
 */
function syncManifest() {
  const folder = DriveApp.getFolderById(FOLDER_ID);
  const manifest = [];

  // Collect all .srt files (excluding manifest.json itself)
  const allFiles = folder.getFiles();
  while (allFiles.hasNext()) {
    const file = allFiles.next();
    const name = file.getName();

    if (!name.toLowerCase().endsWith('.srt')) continue;

    manifest.push({
      name: name,
      url: `https://drive.google.com/file/d/${file.getId()}/view?usp=drive_link`
    });
  }

  // Sort alphabetically so the file is stable / diffable
  manifest.sort((a, b) => a.name.localeCompare(b.name));

  const newContent = JSON.stringify(manifest, null, 2);

  // Find existing manifest.json
  const existing = folder.getFilesByName(MANIFEST_FILENAME);

  if (existing.hasNext()) {
    const manifestFile = existing.next();
    const oldContent = manifestFile.getBlob().getDataAsString();

    // Only write if something actually changed (avoids unnecessary Drive edits)
    if (oldContent.trim() === newContent.trim()) {
      Logger.log('No changes detected — manifest is up to date.');
      return;
    }

    manifestFile.setContent(newContent);
    Logger.log(`Manifest updated: ${manifest.length} SRT file(s).`);
  } else {
    // Create manifest.json if it doesn't exist yet
    folder.createFile(MANIFEST_FILENAME, newContent, MimeType.PLAIN_TEXT);
    Logger.log(`Manifest created with ${manifest.length} SRT file(s).`);
  }
}

/**
 * Call this ONCE manually to install the recurring trigger.
 * After that, syncManifest() runs automatically every 5 minutes.
 */
function installTrigger() {
  // Remove any existing triggers for syncManifest to avoid duplicates
  ScriptApp.getProjectTriggers().forEach(trigger => {
    if (trigger.getHandlerFunction() === 'syncManifest') {
      ScriptApp.deleteTrigger(trigger);
    }
  });

  ScriptApp.newTrigger('syncManifest')
    .timeBased()
    .everyMinutes(30)
    .create();

  Logger.log('✅ Trigger installed — syncManifest will run every 30 minutes.');
}

/**
 * Optional: remove the trigger (e.g. if you want to pause syncing).
 */
function uninstallTrigger() {
  ScriptApp.getProjectTriggers().forEach(trigger => {
    if (trigger.getHandlerFunction() === 'syncManifest') {
      ScriptApp.deleteTrigger(trigger);
      Logger.log('Trigger removed.');
    }
  });
}