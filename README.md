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

`Specs/<PodName>/<version>/<PodName>.podspec.json` — one directory per published version,
written by `pod repo push`. The default branch is `master`: CocoaPods checks out `master`
when it updates a git spec repo.

## Publishing

Requires the source to be registered once:

```bash
pod repo add adapty-specs <this repo URL>
```

Publish all seven pods of an AdaptySDK-iOS ref in dependency order:

```bash
scripts/publish.sh --ios-repo ../AdaptySDK-iOS --ref 4.3.0          # release tag
scripts/publish.sh --ios-repo ../AdaptySDK-iOS --ref <commit SHA>   # untagged build, source pinned to the commit
```

The podspecs are read at the ref, not from the working tree. Pods already published at that
version are skipped, so a run that failed half-way can be repeated; the script fails unless the
spec repo remote ends up with every commit. A version cannot be republished from another ref:
`publish.sh` refuses, so remove the old `Specs/*/<version>` directories or publish a new version
(e.g. `4.2.0-SNAPSHOT.2`). `--skip-import-validation` is passed through to `pod repo push`.
Lint builds every pod for each platform it declares and takes a while.

Tests: `ruby scripts/test/rewrite_source_test.rb`.
