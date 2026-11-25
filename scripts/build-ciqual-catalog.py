"""Convert the French ANSES Ciqual 2025 workbook to KAARIS's offline catalogue."""

import json
import math
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path
from zipfile import ZipFile

NS = {"s": "http://schemas.openxmlformats.org/spreadsheetml/2006/main"}
COLUMNS = {
    "K": "energyKcal", "P": "proteinG", "Q": "carbsG", "R": "fatG", "AA": "fiberG",
    "AY": "calcium", "BB": "iron", "BC": "iodine", "BD": "magnesium",
    "BF": "phosphorus", "BG": "potassium", "BH": "selenium", "BI": "sodium", "BJ": "zinc",
    "BK": "vitaminA", "BN": "vitaminD", "BR": "vitaminE", "BS": "vitaminK",
    "BU": "vitaminC", "BV": "vitaminB1", "BW": "vitaminB2", "BX": "vitaminB3",
    "BY": "vitaminB5", "BZ": "vitaminB6", "CA": "vitaminB9", "CE": "vitaminB12",
}


def sheet_rows(path):
    with ZipFile(path) as workbook:
        strings = []
        if "xl/sharedStrings.xml" in workbook.namelist():
            shared = ET.fromstring(workbook.read("xl/sharedStrings.xml"))
            strings = ["".join(t.text or "" for t in cell.findall(".//s:t", NS)) for cell in shared]
        sheet = ET.fromstring(workbook.read("xl/worksheets/sheet1.xml"))

    for row in sheet.findall("s:sheetData/s:row", NS):
        cells = {}
        for cell in row.findall("s:c", NS):
            column = re.match(r"[A-Z]+", cell.attrib["r"]).group()
            value = cell.findtext("s:v", default="", namespaces=NS)
            if cell.get("t") == "s":
                value = strings[int(value)]
            elif cell.get("t") == "inlineStr":
                value = "".join(t.text or "" for t in cell.findall(".//s:t", NS))
            cells[column] = value.strip()
        yield cells


def measured(value):
    # A trace, a censored measurement (<x) and a missing measurement all
    # lack an exact quantity. An explicit numerical zero remains a value.
    try:
        amount = float(value.replace(",", "."))
    except ValueError:
        return None
    if amount < 0 or not math.isfinite(amount):
        return None
    return round(amount, 8)


def main(workbook, destination):
    rows = sheet_rows(workbook)
    header = next(rows)
    if (header.get("G"), header.get("H")) != ("alim_code", "alim_nom_fr") or any(
        field not in header for field in COLUMNS
    ):
        raise ValueError("Expected the French Ciqual 2025 composition sheet")
    foods = []
    for row in rows:
        if not row.get("G") or not row.get("H"):
            continue
        nutrients = {}
        for column, key in COLUMNS.items():
            value = measured(row.get(column, ""))
            if value is not None:
                nutrients[key] = value
        foods.append({"id": row["G"], "name": " ".join(row["H"].split()), "per100": nutrients})
    if len(foods) != 3484 or len({food["id"] for food in foods}) != len(foods):
        raise ValueError("Unexpected catalogue size or duplicate food codes")
    encoded = [json.dumps(food, ensure_ascii=False, separators=(",", ":")) for food in foods]
    Path(destination).write_text("[\n" + ",\n".join(encoded) + "\n]\n", encoding="utf-8")
    print(f"{len(foods)} foods, {len(COLUMNS)} tracked data columns")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit("Usage: build-ciqual-catalog.py CIQUAL_2025.xlsx OUTPUT.json")
    main(*sys.argv[1:])
