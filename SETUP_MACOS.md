# macOS Setup Instructions

## Issue: Xcode Command Line Tools Not Found

The error `xcrun: error: unable to find utility "xcodebuild"` means Xcode command line tools are not installed or configured.

## Solution

### Option 1: Install Command Line Tools (Recommended if you don't have Xcode)

Run this command in Terminal:

```bash
xcode-select --install
```

This will open a dialog asking you to install the command line tools. Click "Install" and wait for it to complete.

### Option 2: If Xcode is Already Installed

If you have Xcode.app installed but it's not selected, run:

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
```

You may need to accept the Xcode license:

```bash
sudo xcodebuild -license accept
```

### Option 3: Install Full Xcode from App Store

1. Open the Mac App Store
2. Search for "Xcode"
3. Install Xcode (this is a large download, ~10GB+)
4. Open Xcode once to complete setup
5. Accept the license agreement

## After Installation

Once the command line tools are installed, verify with:

```bash
xcodebuild -version
```

You should see something like:
```
Xcode 15.0
Build version 15A240d
```

Then try running Flutter again:

```bash
flutter run -d macos
```

## Additional Notes

- The command line tools are sufficient for Flutter development (you don't need the full Xcode app)
- The installation can take 10-30 minutes depending on your internet connection
- You may need to restart your terminal after installation

