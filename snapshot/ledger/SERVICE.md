# PlantCare

Exchange full plant-library snapshots through the app's backup files containing plants, rooms, zones, photos, and settings.

## What it can do

Exchange full plant-library snapshots through the app's backup files containing plants, rooms, zones, photos, and settings.

## How to call it

<!-- svcmap:generated:implemented:start -->
### AI plant analysis
```console
$ plantcare-cli identify leaf.jpg --api-key <key>
```
<!-- svcmap:generated:implemented:end -->

## Files this service reads or writes

_See the structured authority for verified file contracts._

## Access and prerequisites

_See each implemented call record._

## Planned

- Backup archive: BackupService imports UIKit, so its performBackup/restoreFromBackup cannot compile as a macOS SPM CLI; the archive logic is iOS-runtime-bound. Not headless-wrappable without extracting the Codable logic away from UIKit.
- Clipboard import: Parsing and batch persistence live inside ImportPlantsView.parseClipboard()/performImport(), coupled to SwiftUI @State and the room-mapping screens; no standalone importer exists. GUI-only.
- Care reminders feed: allOverdueCareSteps + scheduleDailyPlantCareReminders depend on the app's UserDefaults-backed DataStore and iOS UserNotifications environment; needs to run in the app process, not a macOS CLI.

```svcmap-card-json
{
  "implemented": [
    {
      "call": {
        "argv": [
          "plantcare-cli",
          "identify",
          "leaf.jpg",
          "--api-key",
          "<key>"
        ],
        "result": "calls OpenAIService.identifyPlant, prints the model's answer"
      },
      "kind": "callable",
      "label": "AI plant analysis",
      "surface_ref": {
        "command": "plantcare-cli",
        "record_id": "PlantCare/cli/plantcare-cli",
        "surface": "cli"
      }
    }
  ],
  "planned": [
    {
      "kind": "callable",
      "label": "Backup archive",
      "owner_unit": "PlantCare/wave3-detector-gap",
      "plan_path": "/Users/aidan/.claude/skills/deep-plan/runs/servicemap-program/wave1-findings.md",
      "reason": "BackupService imports UIKit, so its performBackup/restoreFromBackup cannot compile as a macOS SPM CLI; the archive logic is iOS-runtime-bound. Not headless-wrappable without extracting the Codable logic away from UIKit."
    },
    {
      "kind": "callable",
      "label": "Clipboard import",
      "owner_unit": "PlantCare/wave3-detector-gap",
      "plan_path": "/Users/aidan/.claude/skills/deep-plan/runs/servicemap-program/wave1-findings.md",
      "reason": "Parsing and batch persistence live inside ImportPlantsView.parseClipboard()/performImport(), coupled to SwiftUI @State and the room-mapping screens; no standalone importer exists. GUI-only."
    },
    {
      "kind": "callable",
      "label": "Care reminders feed",
      "owner_unit": "PlantCare/wave3-detector-gap",
      "plan_path": "/Users/aidan/.claude/skills/deep-plan/runs/servicemap-program/wave1-findings.md",
      "reason": "allOverdueCareSteps + scheduleDailyPlantCareReminders depend on the app's UserDefaults-backed DataStore and iOS UserNotifications environment; needs to run in the app process, not a macOS CLI."
    }
  ],
  "project": "PlantCare",
  "schema_version": 1,
  "source": {
    "decisions_file": "/Users/aidan/Dev/PlantCare/ledger/decisions.json",
    "fingerprint": "685e5312e77798d5ecde444b08ef235d9d3e824aad7b8d0357fa11ac33f71d50",
    "project": "PlantCare"
  },
  "summary": "Exchange full plant-library snapshots through the app's backup files containing plants, rooms, zones, photos, and settings."
}
```
