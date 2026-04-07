# Wallpaper Spanner

Wallpaper Spanner is a small macOS utility that takes one image or one video and spans it across every connected display.

- Images are sliced per screen and applied as real desktop wallpapers.
- Videos run in desktop-level windows behind the icons, so the app has to stay open while video mode is active.
- The layout preview uses your current macOS display arrangement, so three side-by-side screens work as one wide canvas.

## Build and run

For development:

```bash
swift run WallpaperSpanner
```

To run the layout tests:

```bash
swift test
```

To build a bundled app:

```bash
./Scripts/make-app.sh
open dist/WallpaperSpanner.app
```

## Notes

- The video mode is a pragmatic workaround for a platform limitation. Public macOS APIs let apps set static wallpapers, but not true video wallpapers.
- Rendered wallpaper slices are written to `~/Library/Application Support/WallpaperSpanner/RenderedWallpapers/`.
