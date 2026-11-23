import csv
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
SOURCE_DIR = SOURCE_DIR = BASE_DIR / "ml-1m" / "ml-1m"
OUTPUT_DIR = BASE_DIR / "import"

OUTPUT_DIR.mkdir(exist_ok=True)

files = {
    "movies": ["movieId", "title", "genres"],
    "ratings": ["userId", "movieId", "rating", "timestamp"],
    "users": ["userId", "gender", "age", "occupation"],
}

for name, headers in files.items():
    source = SOURCE_DIR / f"{name}.dat"
    destination = OUTPUT_DIR / f"{name}.csv"

    count = 0

    with source.open(encoding="latin-1") as infile, \
            destination.open("w", encoding="utf-8", newline="") as outfile:

        writer = csv.writer(outfile)
        writer.writerow(headers)

        for line in infile:
            values = line.rstrip("\r\n").split("::")
            writer.writerow(values[:len(headers)])
            count += 1

    print(f"{name}.csv: {count:,} records converted")