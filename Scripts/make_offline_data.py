#!/usr/bin/env python3
"""Builds the demo app's offline character set: roughly what a sixth-grader reads.

Two lists from Unicode's Unihan database, combined:
- `kGradeLevel` 1-6: the Hong Kong primary-school grade by which a character should be known
  (~2,600 Traditional characters). It has gaps (e.g. 書, 和, 裡), hence the second list.
- The most frequent characters by `kHanyuPinlu` (counts from 現代漢語頻率詞典). Mainland primary
  schools expect ~3,000 characters recognized by the end of grade 6, so the default is 3,000.
Each character's Traditional and Simplified counterparts are added, so both scripts are covered.
Stroke data comes from the hanzi-writer-data npm package.

Usage: python3 Scripts/make_offline_data.py [--max-grade 6] [--top 3000] [--out DIR]

Writes <out>/<character>.json for each character that has stroke data, plus <out>/characters.tsv
(character, HK grade or blank, frequency rank or blank) and the Arphic license. Characters without
stroke data are reported and left to the app's CDN fallback.
"""
import argparse
import io
import os
import re
import shutil
import sys
import tarfile
import urllib.request
import zipfile

UNIHAN_URL = "https://www.unicode.org/Public/UCD/latest/ucd/Unihan.zip"
DATA_VERSION = "2.0.1"
DATA_URL = f"https://registry.npmjs.org/hanzi-writer-data/-/hanzi-writer-data-{DATA_VERSION}.tgz"


def fetch(url):
    print(f"Downloading {url}", file=sys.stderr)
    with urllib.request.urlopen(url, timeout=120) as response:
        return response.read()


def unihan_field(lines, field):
    for line in lines:
        parts = line.rstrip("\n").split("\t")
        if len(parts) == 3 and parts[1] == field:
            yield chr(int(parts[0][2:], 16)), parts[2]


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--max-grade", type=int, default=6)
    parser.add_argument("--top", type=int, default=3000, help="most frequent characters to include")
    parser.add_argument("--out", default="Demo/HanziStrokeDemoApp/HanziData.bundle")
    args = parser.parse_args()

    with zipfile.ZipFile(io.BytesIO(fetch(UNIHAN_URL))) as z:
        dictionary = z.read("Unihan_DictionaryLikeData.txt").decode("utf-8").splitlines()
        variants = z.read("Unihan_Variants.txt").decode("utf-8").splitlines()
        readings = z.read("Unihan_Readings.txt").decode("utf-8").splitlines()

    grades = {c: int(v) for c, v in unihan_field(dictionary, "kGradeLevel") if int(v) <= args.max_grade}
    counterparts = {}
    for name in ("kSimplifiedVariant", "kTraditionalVariant"):
        for c, v in unihan_field(variants, name):
            counterparts.setdefault(c, []).extend(chr(int(u[2:], 16)) for u in v.split())
    counts = {c: sum(int(n) for n in re.findall(r"\((\d+)\)", v)) for c, v in unihan_field(readings, "kHanyuPinlu")}
    by_frequency = sorted(counts, key=lambda c: (-counts[c], ord(c)))
    rank = {c: i + 1 for i, c in enumerate(by_frequency)}

    # Grade list first (by grade), then frequent characters (by rank), each followed by its counterparts.
    seeds = sorted(grades, key=lambda c: (grades[c], ord(c))) + by_frequency[:args.top]
    entries, seen = [], set()
    for c in seeds:
        for x in [c] + counterparts.get(c, []):
            if x not in seen:
                seen.add(x)
                entries.append((x, grades.get(x, ""), rank.get(x, "")))

    # Read only the files we need, by exact member name; never extract the whole archive.
    with tarfile.open(fileobj=io.BytesIO(fetch(DATA_URL)), mode="r:gz") as tar:
        members = {m.name: m for m in tar.getmembers() if m.isfile()}

        def read(name):
            m = members.get(f"package/{name}")
            return tar.extractfile(m).read() if m else None

        if os.path.isdir(args.out):
            shutil.rmtree(args.out)
        os.makedirs(args.out)

        kept, missing, total = [], [], 0
        for c, g, r in entries:
            data = read(f"{c}.json")
            if data is None:
                missing.append(c)
                continue
            with open(os.path.join(args.out, f"{c}.json"), "wb") as f:
                f.write(data)
            kept.append((c, g, r))
            total += len(data)

        license_text = read("ARPHICPL.TXT")
        if license_text:
            with open(os.path.join(args.out, "ARPHICPL.TXT"), "wb") as f:
                f.write(license_text)

    with open(os.path.join(args.out, "characters.tsv"), "w", encoding="utf-8") as f:
        f.write("character\thk_grade\tfrequency_rank\n")
        for c, g, r in kept:
            f.write(f"{c}\t{g}\t{r}\n")

    print(f"Wrote {len(kept)} characters ({total / 1e6:.1f} MB) to {args.out}", file=sys.stderr)
    if missing:
        print(f"No stroke data for {len(missing)} (CDN fallback will report not found): {''.join(missing)}",
              file=sys.stderr)


if __name__ == "__main__":
    main()
