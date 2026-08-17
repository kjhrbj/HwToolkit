# -*- coding: utf-8 -*-
"""将 QueryoverSubcase 导出的 CSV 转成带高亮的 xlsx。

用法: write_excel <input.csv> <output.xlsx> [threshold]

可选 threshold 许用强度：
  提供时按 MaxValue / threshold 比值着色：
    >1 红 / 0.8~1 黄 / <0.8 不着色
  未提供时不进行着色。

分发说明：
  目标用户可能没有 Python，用 PyInstaller 打包成本目录 bin/ 下的 write_excel.exe：
    pip install openpyxl pyinstaller
    pyinstaller --onefile --name write_excel write_excel.py
  然后把 dist/write_excel.exe 放到 hv/scripts/bin/ 即可随插件分发。
"""
import csv
import sys

from openpyxl import Workbook
from openpyxl.styles import Font, PatternFill, Alignment
from openpyxl.utils import get_column_letter

HEADER_FILL = "FFD9E1F2"


def color_for_threshold(v, threshold):
    # 相对许用强度着色：<0.8 不着色 / 0.8~1 黄 / >1 红
    # 返回 8 位不透明 ARGB，避免 alpha=00 在个别 Excel 版本中显示为透明
    ratio = v / threshold if threshold else 0.0
    if ratio > 1.0:
        return "FFFF0000"
    if ratio >= 0.8:
        return "FFFFFF00"
    return None


def main(csv_path, xlsx_path, threshold=None):
    if threshold:
        threshold = float(threshold)
    else:
        threshold = None

    with open(csv_path, "r", encoding="utf-8-sig") as f:
        rows = list(csv.reader(f))

    if not rows:
        raise SystemExit("CSV is empty")

    header = rows[0]
    # 找 MaxValue 所在列（找不到默认第 3 列）
    max_col = header.index("MaxValue") if "MaxValue" in header else 2

    wb = Workbook()
    ws = wb.active
    ws.title = "MaxStress"

    # 表头：加粗 + 浅蓝底 + 居中
    for c, h in enumerate(header, start=1):
        cell = ws.cell(row=1, column=c, value=h)
        cell.font = Font(bold=True)
        cell.fill = PatternFill("solid", fgColor=HEADER_FILL)
        cell.alignment = Alignment(horizontal="center")

    # 数据行 + 着色
    for ri, r in enumerate(rows[1:], start=2):
        for c, val in enumerate(r, start=1):
            col_name = header[c - 1] if c - 1 < len(header) else ""
            if col_name == "MaxValue":
                try:
                    ws.cell(row=ri, column=c, value=int(round(float(val))))
                except (ValueError, TypeError):
                    ws.cell(row=ri, column=c, value=val)
            elif col_name == "@EntityID":
                try:
                    ws.cell(row=ri, column=c, value=int(float(val)))
                except (ValueError, TypeError):
                    ws.cell(row=ri, column=c, value=val)
            else:
                ws.cell(row=ri, column=c, value=val)
        # 只在使用许用强度时着色；留空或比值<0.8 则不填色
        if threshold is not None:
            try:
                v = float(r[max_col])
                fill = color_for_threshold(v, threshold)
                if fill:
                    ws.cell(row=ri, column=max_col + 1).fill = PatternFill(
                        "solid", fgColor=fill
                    )
            except (ValueError, IndexError):
                pass

    # 列宽自适应（最多看前 100 行）
    for c in range(1, len(header) + 1):
        width = 10
        for ri in range(1, min(len(rows) + 1, 101)):
            val = ws.cell(row=ri, column=c).value
            if val is not None:
                width = max(width, len(str(val)) + 2)
        ws.column_dimensions[get_column_letter(c)].width = width

    # 冻结首行
    ws.freeze_panes = "A2"

    wb.save(xlsx_path)
    print(xlsx_path)


if __name__ == "__main__":
    if len(sys.argv) not in (3, 4):
        raise SystemExit("usage: write_excel <in.csv> <out.xlsx> [threshold]")
    threshold = sys.argv[3] if len(sys.argv) == 4 else None
    main(sys.argv[1], sys.argv[2], threshold)
