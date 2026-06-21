from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
ICON_PATH = ROOT / "ios/App/App/Assets.xcassets/AppIcon.appiconset/AppIcon-512@2x.png"
SPLASH_DIR = ROOT / "ios/App/App/Assets.xcassets/Splash.imageset"


def draw_mark(size: int, background: tuple[int, int, int]) -> Image.Image:
    image = Image.new("RGB", (size, size), background)
    draw = ImageDraw.Draw(image)
    scale = size / 1024

    def box(values):
        return tuple(int(value * scale) for value in values)

    draw.rounded_rectangle(box((0, 0, 1024, 1024)), radius=int(220 * scale), fill="#4c2756")
    draw.ellipse(box((212, 242, 812, 842)), outline="#f7deef", width=int(88 * scale))
    draw.arc(box((212, 242, 812, 842)), start=200, end=340, fill="#c99737", width=int(82 * scale))
    crown = [box((350, 300, 350, 300))[:2], box((428, 372, 428, 372))[:2],
             box((512, 230, 512, 230))[:2], box((596, 372, 596, 372))[:2],
             box((674, 300, 674, 300))[:2], box((644, 476, 644, 476))[:2],
             box((380, 476, 380, 476))[:2]]
    draw.polygon(crown, fill="#fff7e8", outline="#c99737")
    width = max(1, int(42 * scale))
    draw.line(box((438, 646, 586, 646)), fill="#ffffff", width=width)
    draw.line(box((536, 596, 586, 646)), fill="#ffffff", width=width)
    draw.line(box((586, 646, 536, 696)), fill="#ffffff", width=width)
    return image


def main() -> None:
    ICON_PATH.parent.mkdir(parents=True, exist_ok=True)
    draw_mark(1024, (76, 39, 86)).save(ICON_PATH)

    splash = Image.new("RGB", (2732, 2732), "#fff7fc")
    mark = draw_mark(768, (76, 39, 86))
    splash.paste(mark, ((2732 - 768) // 2, (2732 - 768) // 2))
    for filename in (
        "splash-2732x2732.png",
        "splash-2732x2732-1.png",
        "splash-2732x2732-2.png",
    ):
        splash.save(SPLASH_DIR / filename)


if __name__ == "__main__":
    main()
