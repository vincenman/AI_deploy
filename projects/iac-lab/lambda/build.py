"""Build lambda-deployment.zip from handler.py. Run: python build.py"""
import zipfile
from pathlib import Path

here = Path(__file__).resolve().parent
zip_path = here / "lambda-deployment.zip"

with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zf:
    zf.write(here / "handler.py", arcname="handler.py")

print(f"Built {zip_path} ({zip_path.stat().st_size} bytes)")
