# Android Release Runbook

How to cut and upload a signed Play release for the SunKidz LMS app.

All paths below are relative to the repo root unless shown otherwise.

## Current state

Last built bundle (21 Sep 2026):

| Field | Value |
| --- | --- |
| Version name | 1.0.2 |
| Version code | 20 |
| Package | `com.lms.sun_kidz_new` |
| targetSdk / compileSdk | 36 (Android 16) |
| minSdk | 24 |
| Size | 74 MB |
| AAB path | `mobile/build/app/outputs/bundle/release/app-release.aab` |

The release live on Play before this was **version code 15, version name 1.0.0**, released 28 Jun.

Mind the drift: `pubspec.yaml` had been sitting at `1.0.1+8`, far below what Play had actually
received. This repo is not a record of what is live — always check Play Console before picking a
version code.

Codes 16 through 19 were skipped deliberately. See [Troubleshooting](#troubleshooting).

## Signing key

There are **two keystores** with nearly identical names. Only one is the registered upload key.
Getting this wrong is what caused the failed uploads.

| | Real upload key | Decoy — do not use |
| --- | --- | --- |
| Path | `mobile/upload-keystore.jks` | `mobile/android/app/upload-keystore.jks` |
| SHA1 | `5D:FF:A0:A9:A1:8E:2A:4E:00:ED:79:BD:8D:7D:CB:1E:07:B0:D6:EE` | `87:8D:BE:85:26:94:3E:07:AF:D0:27:62:54:62:54:A3:A4:74:27:E9` |
| Size | 2744 bytes | 2243 bytes |
| Alias | `upload` | `upload` |
| Status | What Play expects | Superseded |

Play expects **`5D:FF:A0:A9:…`** — the file at `mobile/upload-keystore.jks`.

### The stale certificate trap

`mobile/android/upload_certificate.pem` and `mobile/android/app/upload_certificate.pem` are
**stale**. They carry the superseded `87:8D:BE:85:…` fingerprint and no longer describe this Play
account. They are actively misleading and worth deleting.

Do not use those `.pem` files to decide which keystore to sign with. The authority is Play Console:
**Release › Setup › App signing**, which shows the expected upload certificate fingerprint.

### Password

Both the store password and the key password are set in `mobile/android/key.properties`, which
Gradle reads automatically. That file is gitignored and the password is deliberately not recorded
here, since this file is committed.

A keystore can only ever be opened with its own password. If a password is rejected, you have the
wrong *file*, not the wrong password. An existing keystore's password can be changed with
`keytool -storepasswd` and `keytool -keypasswd` without altering the key or its fingerprint, so Play
continues to accept it.

## Build flow

### 1. Confirm the signing config

`mobile/android/key.properties` must point at the real upload keystore:

```properties
storePassword=<the password>
keyPassword=<the password>
keyAlias=upload
storeFile=/Users/ysw/EXORA/sunkidz/mobile/upload-keystore.jks
```

The `storeFile` line is the one that matters — it must end in `mobile/upload-keystore.jks`, **not**
`mobile/android/app/upload-keystore.jks`.

`mobile/android/app/build.gradle.kts` reads this file and falls back to *debug signing* when any of
the four values is missing. A debug-signed AAB is rejected by Play, so a typo here fails quietly at
build time and loudly at upload time.

### 2. Pick the version code

Check the highest code ever used under **Release › App bundle explorer** in Play Console — not the
Releases page, which only shows active ones. Then set both parts in `mobile/pubspec.yaml`:

```yaml
version: <name>+<code>
```

The code (after `+`) must exceed every code Play has ever seen. The name (before `+`) is cosmetic
and just needs to read sensibly to users. Last shipped was `1.0.2+20`.

### 3. Build

```bash
cd /Users/ysw/EXORA/sunkidz/mobile
export JAVA_HOME=/opt/homebrew/opt/openjdk@17
export PATH=$JAVA_HOME/bin:$PATH
flutter build appbundle --release
```

The `JAVA_HOME` export is required — there is no system JDK on this machine, and `keytool` and
Gradle both fail without it.

Add `flutter clean && flutter pub get` first only after changing dependencies or upgrading Flutter;
it adds several minutes.

The AAB lands at `mobile/build/app/outputs/bundle/release/app-release.aab`.

### 4. Verify, then upload

Do not skip the next section. Gradle caches aggressively, and a rebuild that finishes in a few
seconds may have reused an earlier bundle.

## Verify before upload

Check the finished bundle, not the config that produced it. Every failed upload so far would have
been caught here in ten seconds.

### Signature

```bash
export PATH=/opt/homebrew/opt/openjdk@17/bin:$PATH
cd /Users/ysw/EXORA/sunkidz/mobile
keytool -printcert -jarfile build/app/outputs/bundle/release/app-release.aab | grep SHA1
```

Must print:

```
SHA1: 5D:FF:A0:A9:A1:8E:2A:4E:00:ED:79:BD:8D:7D:CB:1E:07:B0:D6:EE
```

Anything else — especially `87:8D:BE:85:…` — means the wrong keystore was used. Fix
`key.properties` and rebuild.

### Version code

The version code lives in the bundle's protobuf manifest, so read it out of the bytes:

```bash
S=$(mktemp -d)
unzip -o -q build/app/outputs/bundle/release/app-release.aab "base/manifest/*" -d $S
OFF=$(grep -abo "versionCode" $S/base/manifest/AndroidManifest.xml | head -1 | cut -d: -f1)
xxd -s $OFF -l 16 $S/base/manifest/AndroidManifest.xml
strings $S/base/manifest/AndroidManifest.xml | grep -A1 versionName | head -3
```

The code shows as readable ASCII just after the `versionCode` label — for example
`versionCode..20`. Swap `versionCode` for `targetSdkVersion` in the same commands to confirm the
SDK level.

A faster sanity check on version alone is `grep flutter.version mobile/android/local.properties`,
which Flutter regenerates each build. It reflects what was fed to Gradle, though, not what ended up
in the bundle — so prefer the manifest read when it matters.

## Troubleshooting

### "Signed with the wrong key"

> Your App Bundle is expected to be signed with the certificate with fingerprint SHA1:
> 5D:FF:A0:A9:… but the certificate used to sign the App Bundle you uploaded has fingerprint
> SHA1: 87:8D:BE:85:…

`key.properties` is pointing at the decoy keystore. Set `storeFile` to `mobile/upload-keystore.jks`,
rebuild, and verify the fingerprint before re-uploading.

This one bit twice. The trap is that the `upload_certificate.pem` files committed in this repo match
the *decoy*, so they look authoritative and are not. Trust only the fingerprint Play Console shows
under **Release › Setup › App signing**, or the exact fingerprint quoted in the rejection message.

### "Version code N has already been used"

Play reserves a version code permanently once any artifact carries it — including drafts, archived
bundles, and internal-testing uploads. The Releases page shows only *active* codes, so a code can
look free and be taken. This is why 16 was rejected while the page showed only 15.

Open **Release › App bundle explorer** for the full history, then bump past the highest. Jumping
several codes at once is free and avoids another round trip; codes run to roughly 2.1 billion.

### Gradle wrapper download times out

A build failing with `java.net.ConnectException: Operation timed out` in `org.gradle.wrapper.Download`
means the wrapper cannot fetch its distribution, even when general networking is fine. Download it
directly and drop it where the wrapper looks — it skips the download when the zip is already present:

```bash
D=~/.gradle/wrapper/dists/gradle-8.14-all/c2qonpi39x1mddn7hk5gh9iqj
rm -f "$D"/gradle-8.14-all.zip.part "$D"/gradle-8.14-all.zip.lck
curl -sL -o "$D/gradle-8.14-all.zip" https://services.gradle.org/distributions/gradle-8.14-all.zip
```

The hash directory name varies by Gradle version; take it from whatever already exists under
`~/.gradle/wrapper/dists/`, and match the version to `distributionUrl` in
`mobile/android/gradle/wrapper/gradle-wrapper.properties`.

### A rebuild finishes suspiciously fast

Gradle reuses compiled artifacts, so a re-sign can complete in a few seconds. That is normal — but
confirm the signature and version out of the finished bundle rather than assuming the change took.
`rm -f` the AAB before rebuilding so a stale file cannot be mistaken for a fresh one.

## Environment

| Tool | Version / path |
| --- | --- |
| Flutter | 3.47.4 stable, `/opt/homebrew/share/flutter` |
| Dart | 3.13.3 |
| JDK | 17, `/opt/homebrew/opt/openjdk@17` (no system JDK — must be exported) |
| Android SDK | `/opt/homebrew/share/android-commandlinetools` |
| Gradle | 8.14 |
| AGP | 8.11.1 |
| Kotlin | 2.2.20 |

Flutter emits deprecation warnings during the build for Gradle, AGP and Kotlin, asking for 9.1.0,
9.0.1 and 2.3.20 respectively. These are future deprecations, not Play requirements, and the build
succeeds. Upgrading is optional housekeeping, best done well before a release rather than during one.

`compileSdk` and `targetSdk` are not pinned in `build.gradle.kts` — they inherit Flutter's defaults,
currently 36. A Flutter upgrade can therefore move the target SDK on its own, which is usually what
you want, since Play requires a recent target.

## Open cleanup

None of these block a release, but all are worth doing.

- **Back up the upload key off this machine.** `mobile/upload-keystore.jks` is the only copy of the
  key that can update this listing. Losing it means the app can never be updated under this package
  name again.
- **Gitignore the keystore.** `mobile/upload-keystore.jks` is untracked and *not* covered by
  `.gitignore`, so it is one `git add -A` away from being committed. `key.properties` is already
  ignored.
- **Delete the stale certificates.** `mobile/android/upload_certificate.pem` and
  `mobile/android/app/upload_certificate.pem` describe the superseded key and caused the wrong-key
  uploads.
- **Retire the decoy keystore.** `mobile/android/app/upload-keystore.jks` is not the upload key. Its
  password was changed on 21 Sep 2026; a copy with the original password is at
  `~/sunkidz-upload-keystore-backup.jks`.
