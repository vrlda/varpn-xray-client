# iOS native framework

`LibXray.xcframework` is generated from [XTLS/libXray](https://github.com/XTLS/libXray) and is intentionally excluded from Git because the complete framework is larger than GitHub's 100 MB per-file limit.

From the repository root, install the native build tools and run:

```bash
go install golang.org/x/mobile/cmd/gomobile@latest
gomobile init
PYTHON_BIN=/path/to/python3.12 ./scripts/build_libxray_apple.sh
```

The script writes the generated framework to this directory. Do not commit the generated directory; `.gitignore` keeps it local.
