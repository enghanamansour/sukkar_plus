"""
Generates SYNTHETIC earlier reports for the demo persona (same layout as generate_reports.py),
so the app can demonstrate historical comparison. Values are invented for demonstration only.

Demo persona history:
  - demo_history_2026-06.pdf : 30-day AGP, June 2026  (compatible with the August report)
  - demo_history_2026-07.pdf : 14-day AGP, July 2026  (different period length -> limited comparison)
  - report_patient_3.pdf     : 30-day AGP, August 2026 (from the supplied sample set)
Run from this folder:  python3 generate_demo_history.py
"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
src = open(os.path.join(HERE, "generate_reports.py"), encoding="utf-8").read()
defs = src.split("# 4.")[0]  # only the chart + PDF helpers, not the 20-patient loop

def make(days, out, **p):
    code = defs.replace('"30-Day AGP Summary Report"', f'"{days}-Day AGP Summary Report"') \
               .replace('"30-Day Daily Detailed Log"', f'"{days}-Day Daily Detailed Log"') \
               .replace('of 30"', f'of {days}"')
    ns = {}
    exec(compile(code, "generate_reports.py", "exec"), ns)
    base = {"id": out, "name": "Fatima Al-Qahtani", "dob": "12/05/2002", "age": 24,
            "device": "Omnipod 5 & Dexcom G7", "auto_mode": "65%", "target_glucose": 110, "ic_ratio": 10}
    base.update(p)
    ns["create_patient_pdf"](base, os.path.join(HERE, "demo", out + ".pdf"))
    print("generated", out)

make(30, "demo_history_2026-06", report_date="30/06/2026", date_range="01/06/2026-30/06/2026",
     very_high=15.0, high=24.0, tir=41.0, low=11.0, very_low=9.0, avg_glucose=175, gmi=7.5, cv=37.0, sd=65.0)
make(14, "demo_history_2026-07", report_date="28/07/2026", date_range="15/07/2026-28/07/2026",
     very_high=13.0, high=23.0, tir=44.0, low=11.0, very_low=9.0, avg_glucose=170, gmi=7.4, cv=36.0, sd=61.0)
