"""Deterministic 32px pixel art, exported at 64px using nearest-neighbor scaling.

Art brief: transparent background; shallow ceramic plate in the game's oblique
view; dark blue outline, cool grey rim, ivory centre; dirty variant has brown
sauce and green crumbs. Same silhouette and placement for vertical stacking.
"""
from pathlib import Path
from PIL import Image, ImageDraw


def drawPlate(isDirty: bool) -> Image.Image:
    image = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    outline = "#293446"
    draw.ellipse((3, 11, 28, 24), fill=outline)
    draw.ellipse((4, 11, 27, 22), fill="#768ca1")
    draw.ellipse((3, 8, 28, 22), fill=outline)
    draw.ellipse((4, 9, 27, 21), fill="#b9ced8")
    draw.ellipse((5, 9, 26, 19), fill="#eff2df")
    draw.ellipse((7, 11, 24, 19), fill="#829aab")
    draw.ellipse((8, 12, 23, 18), fill="#d3ded9")
    draw.ellipse((9, 12, 22, 17), fill="#f8f4e4")
    draw.line((8, 10, 13, 9), fill="#ffffff", width=1)
    draw.line((8, 21, 23, 21), fill="#d9e4df", width=1)
    if isDirty:
        draw.polygon([(10, 13), (14, 12), (17, 13), (18, 15),
                      (22, 15), (22, 17), (17, 18), (12, 17),
                      (9, 15)], fill="#7b4935")
        draw.polygon([(11, 13), (15, 13), (15, 14), (19, 15),
                      (17, 16), (12, 16)], fill="#b67744")
        draw.rectangle((20, 12, 22, 13), fill="#637943")
        draw.point((19, 13), fill="#8caa52")
        draw.rectangle((7, 16, 8, 17), fill="#bd9554")
        draw.point((24, 16), fill="#7b4935")
    return image.resize((64, 64), Image.Resampling.NEAREST)


if __name__ == "__main__":
    outputDir = Path(__file__).resolve().parents[2] / "assets" / "images" / "item"
    for dirty, filename in [(False, "item_plate.png"), (True, "item_dirtyplate.png")]:
        outputPath = outputDir / filename
        if outputPath.exists():
            raise FileExistsError(f"Refusing to overwrite existing artwork: {outputPath}")
        drawPlate(dirty).save(outputPath)
        print(outputPath)
