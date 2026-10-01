# AdaptySDK-CocoaPods-Specs

CocoaPods spec repo for the Adapty iOS SDK 4.x pods: `Adapty`, `AdaptyUI`, `AdaptyPlugin`,
`AdaptyUIBuilder`, `AdaptyCodable`, `AdaptyCSimdjson`, `AdaptyLogger`.

CocoaPods trunk becomes read-only on December 2, 2026, so new versions are published here.
The repo holds podspec metadata only; sources are downloaded from
[AdaptySDK-iOS](https://github.com/adaptyteam/AdaptySDK-iOS) by the tag (releases) or the pinned
commit (snapshots) in each spec.

## Usage

Add both sources at the top of the `Podfile`. Declaring any `source` disables the implicit
trunk CDN, so it must be listed explicitly:

```ruby
source 'https://github.com/adaptyteam/AdaptySDK-CocoaPods-Specs.git'
source 'https://cdn.cocoapods.org/'
```

A release publishes the specs here and bumps only the pod version in the SDK podspec that depends
on them (e.g. `react-native-adapty-sdk.podspec`); the client Podfile does not change. A client whose
`Podfile.lock` already has the Adapty pods then runs:

```bash
pod repo update                          # `pod install` does not refresh git spec repos
pod update Adapty AdaptyUI AdaptyPlugin  # the four transitive pods follow
```

Plain `pod install` fails instead: first with the "out-of-date source repos" hint, and once the
repos are refreshed (also with `--repo-update`) with
`In snapshot (Podfile.lock): AdaptyPlugin (= <old>)`, because a bumped development pod does not
unlock its dependencies.

## Layout

`Specs/<PodName>/<version>/<PodName>.podspec.json` — one directory per published version.
The default branch is `main`.

## Publishing

Specs are published from [AdaptySDK-iOS](https://github.com/adaptyteam/AdaptySDK-iOS): pushing a release
tag there runs the **Publish CocoaPods specs** workflow, which lints the pods, waits for an approval and
pushes all new specs of the version in one commit. `main` accepts pushes only from that workflow's
GitHub App and org admins.

The script, its manual and snapshot modes and the release runbook live in AdaptySDK-iOS:
`scripts/cocoapods-specs/publish.sh` and `scripts/README.md`. Published versions are immutable.
