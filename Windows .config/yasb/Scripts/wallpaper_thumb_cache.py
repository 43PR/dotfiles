"""
wallpaper_thumb_cache.py
-------------------------------------------------------------------
Mirrors your wallpaper folder into a lightweight "gallery cache"
folder that YASB's Wallpapers widget points at, so the gallery
popup opens fast even if your source images are huge (4K/8K,
uncompressed PNG screenshots, etc).

- Anything wider/taller than MAX_DIMENSION is downscaled and saved
  as a compressed JPEG.
- Anything already small enough is copied through unchanged (fast
  path, no re-encode).
- Already-cached, up-to-date files are skipped on repeat runs.
- Cache entries whose source image no longer exists are removed.

Usage:
    python wallpaper_thumb_cache.py
    python wallpaper_thumb_cache.py --recursive
    python wallpaper_thumb_cache.py --source "D:\\Wallpapers" --max-dim 1920

Then point YASB's wallpapers widget `image_path` at CACHE_DIR
(printed at the end of the run) instead of your source folder.
-------------------------------------------------------------------
"""

from __future__ import annotations

import argparse
import shutil
import sys
from pathlib import Path

from PIL import Image, ImageOps

IMAGE_EXTS = {".jpg", ".jpeg", ".png", ".bmp", ".webp", ".jfif", ".tif", ".tiff"}

DEFAULT_SOURCE = Path.home() / "Pictures" / "Wallpapers"
DEFAULT_CACHE = Path.home() / "Pictures" / ".yasb_wallpaper_cache"
DEFAULT_MAX_DIMENSION = 2560  # long edge, px - plenty for desktop use
DEFAULT_JPEG_QUALITY = 87


def iter_images(source: Path, recursive: bool):
    pattern = "**/*" if recursive else "*"
    for path in source.glob(pattern):
        if path.is_file() and path.suffix.lower() in IMAGE_EXTS:
            yield path


def needs_rebuild(src: Path, dst: Path) -> bool:
    if not dst.exists():
        return True
    return src.stat().st_mtime > dst.stat().st_mtime


def cache_one(src: Path, dst: Path, max_dim: int, quality: int) -> str:
    """Returns 'copied', 'resized', or 'skipped'."""
    dst.parent.mkdir(parents=True, exist_ok=True)

    if not needs_rebuild(src, dst):
        return "skipped"

    with Image.open(src) as img:
        img = ImageOps.exif_transpose(img)  # respect camera/screenshot rotation
        width, height = img.size

        if max(width, height) <= max_dim:
            # Small enough already - just copy the original bytes through.
            shutil.copy2(src, dst)
            return "copied"

        img.thumbnail((max_dim, max_dim), Image.LANCZOS)
        if img.mode in ("RGBA", "P"):
            img = img.convert("RGB")
        img.save(dst, "JPEG", quality=quality, optimize=True)
        return "resized"


def cache_dest_path(src: Path, source_root: Path, cache_root: Path, max_dim: int) -> Path:
    rel = src.relative_to(source_root)
    with Image.open(src) as img:
        oversized = max(img.size) > max_dim
    # Oversized originals always get re-encoded as .jpg to keep the cache small.
    if oversized and src.suffix.lower() != ".jpg":
        rel = rel.with_suffix(".jpg")
    return cache_root / rel


def prune_orphans(source_root: Path, cache_root: Path, recursive: bool) -> int:
    removed = 0
    if not cache_root.exists():
        return removed
    pattern = "**/*" if recursive else "*"
    for cached in cache_root.glob(pattern):
        if not cached.is_file():
            continue
        rel = cached.relative_to(cache_root)
        # A cached file may have a different extension than its source
        # (png -> jpg after resize), so check by stem, not by exact name.
        candidates = [source_root / rel.parent / (rel.stem + ext) for ext in IMAGE_EXTS]
        if not any(c.exists() for c in candidates):
            cached.unlink()
            removed += 1
    return removed


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE,
                         help=f"Wallpaper source folder (default: {DEFAULT_SOURCE})")
    parser.add_argument("--cache", type=Path, default=DEFAULT_CACHE,
                         help=f"Cache output folder (default: {DEFAULT_CACHE})")
    parser.add_argument("--max-dim", type=int, default=DEFAULT_MAX_DIMENSION,
                         help=f"Max long-edge size in px before downscaling (default: {DEFAULT_MAX_DIMENSION})")
    parser.add_argument("--quality", type=int, default=DEFAULT_JPEG_QUALITY,
                         help=f"JPEG quality for resized images (default: {DEFAULT_JPEG_QUALITY})")
    parser.add_argument("--recursive", action="store_true",
                         help="Also scan subfolders of the source folder")
    args = parser.parse_args()

    if not args.source.exists():
        print(f"Source folder does not exist: {args.source}", file=sys.stderr)
        sys.exit(1)

    args.cache.mkdir(parents=True, exist_ok=True)

    counts = {"copied": 0, "resized": 0, "skipped": 0, "errors": 0}
    for src in iter_images(args.source, args.recursive):
        try:
            dst = cache_dest_path(src, args.source, args.cache, args.max_dim)
            result = cache_one(src, dst, args.max_dim, args.quality)
            counts[result] += 1
        except Exception as exc:  # noqa: BLE001 - report and keep going
            counts["errors"] += 1
            print(f"  ! failed on {src.name}: {exc}", file=sys.stderr)

    removed = prune_orphans(args.source, args.cache, args.recursive)

    print(f"Source:   {args.source}")
    print(f"Cache:    {args.cache}")
    print(f"Resized:  {counts['resized']}")
    print(f"Copied:   {counts['copied']} (already small enough)")
    print(f"Skipped:  {counts['skipped']} (already cached)")
    print(f"Removed:  {removed} (source no longer exists)")
    if counts["errors"]:
        print(f"Errors:   {counts['errors']}")
    print()
    print("Point YASB's wallpapers widget image_path at the cache folder above.")


if __name__ == "__main__":
    main()
