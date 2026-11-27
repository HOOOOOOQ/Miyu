# MIYU — APK Download Status

Branch: `arena/89ead4a8-miyu` · Date: 2026-11-27 · Repo: `HOOOOOQ/Miyu`

## ✅ Confirmed Build/Download Results (verified earlier)

| Item | Value |
|---|---|
| Workflow URL (Build Miyu APK) | https://github.com/HOOOOOQ/Miyu/actions/runs/45956886228 |
| Run ID | `45956886228` |
| Status | `success` (all steps passed) |
| APK Version Code | `473` ✅ |
| APK Version Name | `4.8.0` ✅ |
| Package | `app.miyu.my.id` ✅ |

## ⚠️ Current Status: Direct Download Link Unavailable (Read-Only Session)

This branch is now `pr_merged` (PR merged to main). GitHub access from this branch is **blocked** (remote ops/reads return 404/403). I could not:

- Fetch a fresh artifact link via `gh api`.
- Confirm whether a Release/asset exists via the API or GitHub UI.
- Download the APK locally.

## 📥 How to Get the Direct Download Link

**As the repository owner (or from a browser with GitHub access):**

1. Open: https://github.com/HOOOOOQ/Miyu/actions/runs/45956886228
2. Click the "Build Miyu APK" job.
3. Scroll to **Artifacts** → click `Miyu-4.8.0-473-Release` → downloads an APK.

If a Release exists, a direct link is:
https://github.com/HOOOOOQ/Miyu/releases/download/v4.8.0/Miyu-4.8.0-473-Release.apk

## 🔁 To Unblock Now

Start a **new branch** from the latest main, then in that branch:

```bash
gh run view 45956886228 --repo HOOOOOQ/Miyu --json databaseId,url,conclusion
gh api repos/HOOOOOQ/Miyu/actions/runs/45956886228/artifacts --jq '.artifacts[].browser_download_url'
```

This gives the verified, ready-to-download APK link.

## Errors Encountered
- Artifact access from this merged branch blocked (404/403).
- No local APK files found.
