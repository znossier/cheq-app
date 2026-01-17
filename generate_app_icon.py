#!/usr/bin/env python3
"""
Generate all iOS app icon sizes from a source image.
Usage: python3 generate_app_icon.py path/to/source_image.png
"""
import sys
import os
from pathlib import Path
from PIL import Image

# Icon size definitions based on Contents.json
ICON_SIZES = [
    # iPhone icons
    ("icon-20@2x.png", 40, 40),      # 20pt @ 2x
    ("icon-20@3x.png", 60, 60),      # 20pt @ 3x
    ("icon-29@2x.png", 58, 58),      # 29pt @ 2x
    ("icon-29@3x.png", 87, 87),      # 29pt @ 3x
    ("icon-40@2x.png", 80, 80),      # 40pt @ 2x
    ("icon-40@3x.png", 120, 120),    # 40pt @ 3x
    ("icon-60@2x.png", 120, 120),    # 60pt @ 2x
    ("icon-60@3x.png", 180, 180),    # 60pt @ 3x
    # iPad icons
    ("icon-20-ipad@1x.png", 20, 20),      # 20pt @ 1x
    ("icon-20-ipad@2x.png", 40, 40),      # 20pt @ 2x
    ("icon-29-ipad@1x.png", 29, 29),      # 29pt @ 1x
    ("icon-29-ipad@2x.png", 58, 58),      # 29pt @ 2x
    ("icon-40-ipad@1x.png", 40, 40),      # 40pt @ 1x
    ("icon-40-ipad@2x.png", 80, 80),      # 40pt @ 2x
    ("icon-76-ipad@2x.png", 152, 152),    # 76pt @ 2x
    ("icon-83.5-ipad@2x.png", 167, 167),  # 83.5pt @ 2x
    # Marketing icon
    ("AppIcon-1024.png", 1024, 1024),
]

APPICON_DIR = Path("Assets.xcassets/AppIcon.appiconset")


def validate_source_image(image_path):
    """Validate that the source image exists and meets requirements."""
    if not os.path.exists(image_path):
        raise FileNotFoundError(f"Source image not found: {image_path}")
    
    try:
        with Image.open(image_path) as img:
            width, height = img.size
            if width != height:
                raise ValueError(
                    f"Source image must be square. Got {width}x{height}px"
                )
            if width < 1024:
                raise ValueError(
                    f"Source image should be at least 1024x1024px for best quality. "
                    f"Got {width}x{height}px"
                )
            return width, height
    except Exception as e:
        if isinstance(e, (ValueError, FileNotFoundError)):
            raise
        raise ValueError(f"Failed to open image: {e}")


def generate_icons(source_image_path):
    """Generate all required icon sizes from source image."""
    # Validate source image
    print(f"Validating source image: {source_image_path}")
    validate_source_image(source_image_path)
    
    # Ensure output directory exists
    APPICON_DIR.mkdir(parents=True, exist_ok=True)
    
    # Load source image
    print(f"Loading source image...")
    with Image.open(source_image_path) as source_img:
        # Convert to RGBA if needed (for transparency support)
        if source_img.mode != 'RGBA':
            source_img = source_img.convert('RGBA')
        
        # Generate each icon size
        print(f"Generating {len(ICON_SIZES)} icon sizes...")
        for filename, width, height in ICON_SIZES:
            output_path = APPICON_DIR / filename
            
            # Resize with high-quality LANCZOS resampling
            resized = source_img.resize((width, height), Image.Resampling.LANCZOS)
            
            # Save as PNG
            resized.save(output_path, 'PNG', optimize=True)
            print(f"  ✓ Generated {filename} ({width}x{height}px)")
    
    print(f"\n✓ Successfully generated all icons in {APPICON_DIR}")
    print(f"  Total icons generated: {len(ICON_SIZES)}")


def main():
    """Main entry point."""
    if len(sys.argv) != 2:
        print("Usage: python3 generate_app_icon.py <source_image_path>")
        print("\nExample:")
        print("  python3 generate_app_icon.py icon_source.png")
        print("\nRequirements:")
        print("  - Source image must be square")
        print("  - Source image should be at least 1024x1024px for best quality")
        print("  - Supported formats: PNG, JPEG, etc. (any format PIL supports)")
        sys.exit(1)
    
    source_image_path = sys.argv[1]
    
    try:
        generate_icons(source_image_path)
    except (FileNotFoundError, ValueError) as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Unexpected error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()

