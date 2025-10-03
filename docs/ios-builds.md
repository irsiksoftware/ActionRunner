# iOS Build Integration

Documentation for integrating GitHub-hosted macOS runners with Dakota's self-hosted Windows runners for mobile development.

## Overview

This guide covers the strategy for building iOS apps (like QiFlowGo) using GitHub-hosted macOS runners while leveraging self-hosted Windows runners for Android builds.

**Why macOS is Required for iOS:**
- **Xcode** - Only runs on macOS, required for iOS builds
- **iOS SDK** - Only available on macOS
- **Code signing** - Apple's signing tools are macOS-only
- **App Store submission** - Requires macOS tooling

## Runner Selection Strategy

### Self-Hosted Windows Runner
**Use for:**
- ✅ Android builds (React Native, Unity)
- ✅ .NET libraries and tools
- ✅ Python scripts
- ✅ Windows desktop applications
- ✅ Testing and linting (cross-platform)

**Labels:** `[self-hosted, windows, react-native]`

### GitHub-Hosted macOS Runner
**Use for:**
- ✅ iOS builds (React Native, Unity iOS)
- ✅ macOS desktop applications
- ✅ Xcode projects

**Labels:** `macos-latest`, `macos-13`, `macos-14`

## Cost Analysis

### GitHub-Hosted macOS Runners

**Pricing (as of 2025):**
- **macOS (Large)**: $0.16/minute
- **Included minutes**: Varies by plan
  - Free: 0 minutes for macOS (but unlimited for public repos)
  - Pro: 3,000 general minutes (macOS uses 10x multiplier = 300 minutes)
  - Team: 3,000 general minutes (macOS uses 10x multiplier = 300 minutes)
  - Enterprise: 50,000 general minutes (macOS uses 10x multiplier = 5,000 minutes)

**Example Cost Calculation:**

Assuming typical iOS build takes **15 minutes**:
```
15 minutes × $0.16/min = $2.40 per build
```

Monthly costs for different build frequencies:
- **10 builds/month**: $24
- **50 builds/month**: $120
- **100 builds/month**: $240
- **500 builds/month**: $1,200

### Self-Hosted Mac Mini (Future Alternative)

**One-time Hardware Cost:**
- **Mac Mini M2**: ~$600-800
- **Mac Studio** (more powerful): ~$2,000+

**Monthly Operating Cost:**
- Electricity: ~$5-10/month
- Network/maintenance: Minimal

**Break-even Analysis:**
- At 50 builds/month: 5-7 months to break even with Mac Mini
- At 100 builds/month: 2.5-4 months to break even with Mac Mini
- At 500 builds/month: < 1 month to break even

**Recommendation:**
- **Start with GitHub-hosted** for flexibility and zero upfront cost
- **Consider self-hosted Mac Mini** if iOS builds exceed 100/month
- Monitor costs using GitHub's billing dashboard

## Workflow Examples

### Example 1: React Native Multi-Platform Build (QiFlowGo)

This workflow builds both Android and iOS from the same React Native codebase:

```yaml
name: Mobile Build

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  # Android build on self-hosted Windows runner
  build-android:
    runs-on: [self-hosted, windows, react-native]
    steps:
      - uses: actions/checkout@v4

      - name: Install dependencies
        run: npm ci

      - name: Run tests
        run: npm test

      - name: Lint
        run: npm run lint

      - name: Build Android APK
        run: |
          cd android
          .\gradlew.bat assembleRelease

      - name: Upload Android APK
        uses: actions/upload-artifact@v4
        with:
          name: android-apk
          path: android/app/build/outputs/apk/release/*.apk
          retention-days: 30

  # iOS build on GitHub-hosted macOS runner
  build-ios:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '18'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Install CocoaPods dependencies
        run: |
          cd ios
          pod install

      - name: Build iOS
        run: |
          cd ios
          xcodebuild -workspace QiFlowGo.xcworkspace \
            -scheme QiFlowGo \
            -configuration Release \
            -sdk iphoneos \
            -archivePath $PWD/build/QiFlowGo.xcarchive \
            archive

      - name: Export IPA
        run: |
          cd ios
          xcodebuild -exportArchive \
            -archivePath $PWD/build/QiFlowGo.xcarchive \
            -exportPath $PWD/build \
            -exportOptionsPlist ExportOptions.plist

      - name: Upload iOS IPA
        uses: actions/upload-artifact@v4
        with:
          name: ios-ipa
          path: ios/build/*.ipa
          retention-days: 30

  # Publish artifacts (runs after both builds complete)
  publish:
    needs: [build-android, build-ios]
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - name: Download Android APK
        uses: actions/download-artifact@v4
        with:
          name: android-apk
          path: artifacts/

      - name: Download iOS IPA
        uses: actions/download-artifact@v4
        with:
          name: ios-ipa
          path: artifacts/

      - name: Create Release
        uses: softprops/action-gh-release@v1
        if: startsWith(github.ref, 'refs/tags/')
        with:
          files: |
            artifacts/*.apk
            artifacts/*.ipa
```

### Example 2: iOS-Only Workflow

If you only need iOS builds:

```yaml
name: iOS Build

on:
  push:
    branches: [main]
  pull_request:

jobs:
  build:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4

      - name: Select Xcode version
        run: sudo xcode-select -s /Applications/Xcode_15.0.app

      - name: Show Xcode version
        run: xcodebuild -version

      - name: Install CocoaPods
        run: |
          cd ios
          pod install

      - name: Build and Test
        run: |
          cd ios
          xcodebuild test \
            -workspace QiFlowGo.xcworkspace \
            -scheme QiFlowGo \
            -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.0' \
            -quiet

      - name: Build Release
        run: |
          cd ios
          xcodebuild archive \
            -workspace QiFlowGo.xcworkspace \
            -scheme QiFlowGo \
            -configuration Release \
            -archivePath build/QiFlowGo.xcarchive

      - name: Upload Archive
        uses: actions/upload-artifact@v4
        with:
          name: ios-archive
          path: ios/build/QiFlowGo.xcarchive
```

### Example 3: Conditional Platform Builds

Build only the platform that changed:

```yaml
name: Conditional Mobile Build

on:
  push:
    paths:
      - 'ios/**'
      - 'android/**'
      - 'src/**'

jobs:
  detect-changes:
    runs-on: ubuntu-latest
    outputs:
      ios: ${{ steps.filter.outputs.ios }}
      android: ${{ steps.filter.outputs.android }}
    steps:
      - uses: actions/checkout@v4
      - uses: dorny/paths-filter@v2
        id: filter
        with:
          filters: |
            ios:
              - 'ios/**'
              - 'src/**'
            android:
              - 'android/**'
              - 'src/**'

  build-android:
    needs: detect-changes
    if: needs.detect-changes.outputs.android == 'true'
    runs-on: [self-hosted, windows, react-native]
    steps:
      - uses: actions/checkout@v4
      - name: Build Android
        run: |
          cd android
          .\gradlew.bat assembleRelease

  build-ios:
    needs: detect-changes
    if: needs.detect-changes.outputs.ios == 'true'
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - name: Build iOS
        run: |
          cd ios
          pod install
          xcodebuild archive -workspace QiFlowGo.xcworkspace -scheme QiFlowGo
```

## Best Practices

### 1. Cache Dependencies

**For iOS (CocoaPods):**
```yaml
- name: Cache CocoaPods
  uses: actions/cache@v3
  with:
    path: ios/Pods
    key: ${{ runner.os }}-pods-${{ hashFiles('ios/Podfile.lock') }}
    restore-keys: |
      ${{ runner.os }}-pods-
```

**For React Native (npm):**
```yaml
- name: Setup Node.js
  uses: actions/setup-node@v4
  with:
    node-version: '18'
    cache: 'npm'  # Automatically caches npm dependencies
```

### 2. Matrix Builds for Multiple iOS Versions

```yaml
jobs:
  build-ios:
    runs-on: macos-latest
    strategy:
      matrix:
        xcode: ['14.3', '15.0', '15.2']
    steps:
      - uses: actions/checkout@v4
      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_${{ matrix.xcode }}.app
      - name: Build
        run: xcodebuild build -scheme QiFlowGo
```

### 3. Parallel Jobs for Speed

Run tests and builds in parallel:

```yaml
jobs:
  test:
    runs-on: macos-latest
    steps:
      - name: Run unit tests
        run: xcodebuild test ...

  lint:
    runs-on: macos-latest
    steps:
      - name: Run SwiftLint
        run: swiftlint

  build:
    needs: [test, lint]  # Only build if tests and lint pass
    runs-on: macos-latest
    steps:
      - name: Build release
        run: xcodebuild archive ...
```

### 4. Code Signing for Distribution

For App Store or TestFlight distribution:

```yaml
jobs:
  build-and-sign:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4

      - name: Import signing certificate
        env:
          CERTIFICATE_BASE64: ${{ secrets.IOS_CERTIFICATE_BASE64 }}
          CERTIFICATE_PASSWORD: ${{ secrets.IOS_CERTIFICATE_PASSWORD }}
        run: |
          # Create temporary keychain
          security create-keychain -p temp_password temp.keychain
          security default-keychain -s temp.keychain
          security unlock-keychain -p temp_password temp.keychain

          # Import certificate
          echo $CERTIFICATE_BASE64 | base64 --decode > certificate.p12
          security import certificate.p12 -k temp.keychain -P $CERTIFICATE_PASSWORD -T /usr/bin/codesign

          # Allow codesign to access keychain
          security set-key-partition-list -S apple-tool:,apple: -s -k temp_password temp.keychain

      - name: Import provisioning profile
        env:
          PROVISION_PROFILE_BASE64: ${{ secrets.IOS_PROVISION_PROFILE_BASE64 }}
        run: |
          mkdir -p ~/Library/MobileDevice/Provisioning\ Profiles
          echo $PROVISION_PROFILE_BASE64 | base64 --decode > ~/Library/MobileDevice/Provisioning\ Profiles/profile.mobileprovision

      - name: Build and sign
        run: |
          cd ios
          xcodebuild archive -workspace QiFlowGo.xcworkspace -scheme QiFlowGo -archivePath build/app.xcarchive
          xcodebuild -exportArchive -archivePath build/app.xcarchive -exportPath build -exportOptionsPlist ExportOptions.plist

      - name: Upload to TestFlight
        env:
          APP_STORE_CONNECT_API_KEY: ${{ secrets.APP_STORE_CONNECT_API_KEY }}
        run: |
          xcrun altool --upload-app -f ios/build/*.ipa -t ios --apiKey $APP_STORE_CONNECT_API_KEY
```

## Cost Monitoring

### Track macOS Runner Usage

```yaml
name: Usage Reporter

on:
  schedule:
    - cron: '0 0 * * 0'  # Weekly on Sunday

jobs:
  report-usage:
    runs-on: ubuntu-latest
    steps:
      - name: Get billing info
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          # Get actions minutes usage
          gh api /repos/${{ github.repository }}/actions/cache/usage

          # Note: Actual billing API requires admin token
          # View detailed usage at: https://github.com/settings/billing
```

**Manual Monitoring:**
- Check usage: https://github.com/settings/billing
- Set up spending limits in GitHub billing settings
- Enable billing alerts via email

### Cost Optimization Tips

1. **Use caching** to reduce build times (saves minutes)
2. **Run tests in parallel** on Ubuntu runners first (cheaper), only macOS for iOS-specific tests
3. **Use `if` conditions** to skip unnecessary builds
4. **Set appropriate retention** for artifacts (default 90 days is often too long)
5. **Cancel stale workflow runs** automatically:

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true  # Cancel old runs when new push happens
```

## Future: Self-Hosted Mac Mini Setup

If iOS build frequency justifies the investment, consider:

### Hardware Recommendation
- **Mac Mini M2** (base model): $599
  - 8GB RAM, 256GB storage
  - Sufficient for CI/CD builds
  - Low power consumption (~5-10W idle)

- **Mac Mini M2 Pro** (for heavier workloads): $1,299
  - 16GB RAM, 512GB storage
  - Better for parallel builds

### Setup Process (High-Level)

1. **Install GitHub Actions Runner:**
   ```bash
   mkdir actions-runner && cd actions-runner
   curl -o actions-runner-osx-x64.tar.gz -L https://github.com/actions/runner/releases/download/v2.311.0/actions-runner-osx-x64.tar.gz
   tar xzf ./actions-runner-osx-x64.tar.gz
   ./config.sh --url https://github.com/DakotaIrsik/YOUR-REPO --token YOUR-TOKEN
   ./svc.sh install
   ./svc.sh start
   ```

2. **Install required tools:**
   ```bash
   # Install Xcode from App Store
   # Install Homebrew
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

   # Install CocoaPods
   sudo gem install cocoapods

   # Install Node.js
   brew install node
   ```

3. **Security hardening:**
   - Disable remote login
   - Enable FileVault encryption
   - Set up firewall rules
   - Create dedicated runner account
   - Regular security updates

4. **Workflow configuration:**
   ```yaml
   runs-on: [self-hosted, macOS, xcode]  # Custom labels
   ```

**Pros of Self-Hosted Mac:**
- ✅ No per-minute costs after hardware purchase
- ✅ Full control over environment
- ✅ Can use for other tasks when not building

**Cons of Self-Hosted Mac:**
- ❌ Upfront hardware cost
- ❌ Maintenance burden
- ❌ Power/internet reliability concerns
- ❌ macOS/Xcode updates management
- ❌ Physical space requirement

## Troubleshooting

### Common iOS Build Issues

**"xcodebuild: command not found"**
```yaml
- name: Select Xcode
  run: sudo xcode-select -s /Applications/Xcode_15.0.app
```

**"No signing certificate found"**
- Ensure certificate is imported to keychain
- Check provisioning profile is installed
- Verify certificate hasn't expired

**"Pod install fails"**
```yaml
- name: Update CocoaPods
  run: |
    sudo gem install cocoapods
    cd ios
    pod repo update
    pod install
```

**"Simulator not found"**
```yaml
- name: List available simulators
  run: xcrun simctl list devices

- name: Boot simulator
  run: xcrun simctl boot "iPhone 15"
```

### GitHub-Hosted macOS Runner Specifics

**Available Xcode versions:**
- Check https://github.com/actions/runner-images/blob/main/images/macos/macos-13-Readme.md
- Select specific version: `xcode-select -s /Applications/Xcode_X.X.app`

**Pre-installed software:**
- Node.js, Ruby, Python
- Homebrew
- CocoaPods
- Fastlane
- Full list: GitHub's runner images documentation

## References

- [GitHub Actions: macOS runners](https://docs.github.com/en/actions/using-github-hosted-runners/about-github-hosted-runners#supported-runners-and-hardware-resources)
- [GitHub Actions: Billing](https://docs.github.com/en/billing/managing-billing-for-github-actions/about-billing-for-github-actions)
- [React Native iOS setup](https://reactnative.dev/docs/environment-setup)
- [Xcode command line tools](https://developer.apple.com/xcode/)
- [Fastlane for iOS automation](https://docs.fastlane.tools/)

---

**Last Updated:** 2025-10-03 | Dakota Irsik's Internal Infrastructure
