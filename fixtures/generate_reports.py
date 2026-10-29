import os
import matplotlib.pyplot as plt
import numpy as np
from fpdf import FPDF

# 1. إعداد الرسم البياني لـ AGP Chart بواقعية طبية تامة
def generate_agp_chart_image(patient, filename="agp_chart_temp.png"):
    fig, ax = plt.subplots(figsize=(8, 2.5), dpi=150)
    hours = np.linspace(0, 24, 100)
    
    # محاكاة منحنيات الجلوكوز بناءً على القيم الحقيقية للمريض
    base_val = patient['avg_glucose']
    median_glucose = base_val + 15 * np.sin(hours / 2)
    p75 = median_glucose + patient['sd'] * 0.5
    p25 = median_glucose - patient['sd'] * 0.5
    p95 = median_glucose + patient['sd'] * 1.2
    p5 = median_glucose - patient['sd'] * 1.2
    
    # مناطق الهدف الطبي (Target Range 70-180)
    ax.axhspan(70, 180, color='#e8f5e9', alpha=0.9, label='Target Range')
    ax.axhspan(180, 400, color='#fff3e0', alpha=0.4)
    ax.axhspan(0, 70, color='#ffebee', alpha=0.4)
    
    ax.plot(hours, median_glucose, color='#2e7d32', linewidth=2, label='Median (50%)')
    ax.fill_between(hours, p25, p75, color='#a5d6a7', alpha=0.5)
    ax.fill_between(hours, p5, p95, color='#c8e6c9', alpha=0.3)
    
    ax.axhline(180, color='#4caf50', linestyle='--', linewidth=0.8)
    ax.axhline(70, color='#4caf50', linestyle='--', linewidth=0.8)
    
    ax.set_ylim(0, 350)
    ax.set_xlim(0, 24)
    ax.set_xticks([0, 3, 6, 9, 12, 15, 18, 21, 24])
    ax.set_xticklabels(['12 AM', '3 AM', '6 AM', '9 AM', '12 PM', '3 PM', '6 PM', '9 PM', '12 AM'], fontsize=8)
    ax.set_ylabel('mg/dL', fontsize=8)
    ax.set_title('Ambulatory Glucose Profile (AGP)', fontsize=10, fontweight='bold')
    ax.grid(True, linestyle=':', alpha=0.5)
    
    plt.tight_layout()
    plt.savefig(filename, dpi=150)
    plt.close()

# 2. إعداد الرسم البياني اليومي (Daily Glucose & Insulin)
def generate_daily_chart_image(patient, filename="daily_chart_temp.png"):
    fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(8, 2.5), gridspec_kw={'height_ratios': [2, 1]}, dpi=150)
    hours = np.linspace(0, 24, 150)
    
    glucose = patient['avg_glucose'] + 30 * np.sin(hours / 1.5) + patient['sd'] * 0.3 * np.random.randn(len(hours))
    glucose = np.clip(glucose, 50, 350)
    
    ax1.axhspan(70, 180, color='#e8f5e9', alpha=0.8)
    ax1.plot(hours, glucose, color='#1b5e20', linewidth=1.5)
    ax1.axhline(180, color='#81c784', linestyle='--', linewidth=0.8)
    ax1.axhline(70, color='#e57373', linestyle='--', linewidth=0.8)
    ax1.set_ylim(0, 350)
    ax1.set_xlim(0, 24)
    ax1.set_ylabel('Glucose', fontsize=7)
    ax1.set_xticks([])
    
    bolus_times = [2, 8, 14, 20]
    bolus_units = [2.0, 5.0, 7.5, 4.0]
    ax2.bar(bolus_times, bolus_units, width=0.4, color='#0288d1')
    ax2.set_xlim(0, 24)
    ax2.set_ylim(0, 12)
    ax2.set_xticks([0, 3, 6, 9, 12, 15, 18, 21, 24])
    ax2.set_xticklabels(['12 AM', '3 AM', '6 AM', '9 AM', '12 PM', '3 PM', '6 PM', '9 PM', '12 AM'], fontsize=8)
    ax2.set_ylabel('Bolus (U)', fontsize=7)
    
    plt.tight_layout()
    plt.savefig(filename, dpi=150)
    plt.close()

# 3. بناء هيكلية PDF القياسية
class AGPReport(FPDF):
    def __init__(self, patient_info):
        super().__init__()
        self.patient = patient_info

    def header(self):
        self.set_font("Arial", 'B', 12)
        self.cell(100, 6, self.patient['name'], ln=False)
        self.set_font("Arial", '', 10)
        self.cell(90, 6, "Omnipod Discover(TM)", align='R', ln=True)
        
        self.set_font("Arial", '', 9)
        self.cell(100, 5, f"DOB: {self.patient['dob']} ({self.patient['age']} years old)", ln=False)
        self.cell(90, 5, f"Report Generated: {self.patient['report_date']}", align='R', ln=True)
        
        self.set_font("Arial", 'B', 10)
        self.cell(100, 5, self.patient['report_type'], ln=False)
        self.set_font("Arial", '', 9)
        self.cell(90, 5, f"Date Range: {self.patient['date_range']}", align='R', ln=True)
        
        self.set_draw_color(180, 180, 180)
        self.line(10, self.get_y() + 2, 200, self.get_y() + 2)
        self.ln(5)

    def footer(self):
        self.set_y(-15)
        self.set_font("Arial", 'I', 8)
        self.set_text_color(128, 128, 128)
        self.cell(0, 10, f"Page {self.page_no()} (of 8)  |  Sukkar Plus Medical Analytics", align='C')

def create_patient_pdf(patient, filename):
    agp_img = f"agp_{patient['id']}.png"
    daily_img = f"daily_{patient['id']}.png"
    generate_agp_chart_image(patient, agp_img)
    generate_daily_chart_image(patient, daily_img)

    pdf = AGPReport(patient)
    pdf.set_auto_page_break(auto=True, margin=15)
    
    # PAGE 1: AGP Summary Report
    patient['report_type'] = "30-Day AGP Summary Report"
    pdf.add_page()
    
    pdf.set_font("Arial", 'B', 11)
    pdf.cell(190, 6, "Time in Ranges (Target Range: 70-180 mg/dL)", ln=True)
    
    pdf.set_font("Arial", '', 9)
    pdf.set_fill_color(220, 230, 242)
    pdf.cell(38, 6, "Very High (>250)", border=1, align='C', fill=True)
    pdf.cell(38, 6, "High (181-250)", border=1, align='C', fill=True)
    pdf.cell(38, 6, "Target (70-180)", border=1, align='C', fill=True)
    pdf.cell(38, 6, "Low (54-69)", border=1, align='C', fill=True)
    pdf.cell(38, 6, "Very Low (<54)", border=1, align='C', fill=True, ln=True)
    
    pdf.cell(38, 6, f"{patient['very_high']}%", border=1, align='C')
    pdf.cell(38, 6, f"{patient['high']}%", border=1, align='C')
    pdf.cell(38, 6, f"{patient['tir']}%", border=1, align='C')
    pdf.cell(38, 6, f"{patient['low']}%", border=1, align='C')
    pdf.cell(38, 6, f"{patient['very_low']}%", border=1, align='C', ln=True)
    pdf.ln(4)
    
    pdf.image(agp_img, x=10, y=pdf.get_y(), w=190)
    pdf.ln(60)
    
    pdf.set_font("Arial", 'B', 11)
    pdf.cell(190, 6, "Glucose Metrics & Device Use", ln=True)
    metrics = [
        ("Average Glucose:", f"{patient['avg_glucose']} mg/dL", "GMI:", f"{patient['gmi']}%"),
        ("Glucose Variability (CV):", f"{patient['cv']}%", "Standard Deviation (SD):", f"{patient['sd']} mg/dL"),
        ("Device Used:", patient['device'], "Automated Mode Wear Time:", f"{patient['auto_mode']}%")
    ]
    for row in metrics:
        pdf.set_font("Arial", '', 9)
        pdf.cell(45, 6, row[0], border='TLB')
        pdf.set_font("Arial", 'B', 9)
        pdf.cell(50, 6, row[1], border='TRB')
        pdf.set_font("Arial", '', 9)
        pdf.cell(50, 6, row[2], border='TLB')
        pdf.set_font("Arial", 'B', 9)
        pdf.cell(45, 6, row[3], border='TRB', ln=True)
    pdf.ln(4)

    # PAGES 2 - 7: Daily Detailed Logs
    patient['report_type'] = "30-Day Daily Detailed Log"
    for day_num in range(1, 7):
        pdf.add_page()
        pdf.set_font("Arial", 'B', 11)
        pdf.cell(190, 6, f"Daily Glucose Profile - Day {day_num} of 30", ln=True)
        pdf.ln(2)
        pdf.image(daily_img, x=10, y=pdf.get_y(), w=190)
        pdf.ln(60)
        
        pdf.set_font("Arial", 'B', 8)
        pdf.set_fill_color(230, 230, 230)
        pdf.cell(38, 6, "Time Slot", border=1, align='C', fill=True)
        pdf.cell(38, 6, "Avg Glucose", border=1, align='C', fill=True)
        pdf.cell(38, 6, "Basal (U)", border=1, align='C', fill=True)
        pdf.cell(38, 6, "Bolus (U)", border=1, align='C', fill=True)
        pdf.cell(40, 6, "Carbs (g)", border=1, align='C', fill=True, ln=True)
        
        pdf.set_font("Arial", '', 8)
        time_slots = [
            ("12 AM - 4 AM", f"{patient['avg_glucose']-5} mg/dL", "1.2 U", "0.0 U", "0 g"),
            ("4 AM - 8 AM", f"{patient['avg_glucose']+2} mg/dL", "1.4 U", "3.5 U", "25 g"),
            ("8 AM - 12 PM", f"{patient['avg_glucose']+10} mg/dL", "1.1 U", "5.2 U", "45 g"),
            ("12 PM - 4 PM", f"{patient['avg_glucose']+15} mg/dL", "1.3 U", "6.0 U", "60 g"),
            ("4 PM - 8 PM", f"{patient['avg_glucose']-2} mg/dL", "1.0 U", "4.1 U", "35 g"),
            ("8 PM - 12 AM", f"{patient['avg_glucose']-8} mg/dL", "0.9 U", "1.5 U", "10 g")
        ]
        for slot in time_slots:
            pdf.cell(38, 5, slot[0], border=1, align='C')
            pdf.cell(38, 5, slot[1], border=1, align='C')
            pdf.cell(38, 5, slot[2], border=1, align='C')
            pdf.cell(38, 5, slot[3], border=1, align='C')
            pdf.cell(40, 5, slot[4], border=1, align='C', ln=True)

    # PAGE 8: Device Settings
    patient['report_type'] = "Omnipod 5 Device Settings & Parameters"
    pdf.add_page()
    pdf.set_font("Arial", 'B', 11)
    pdf.cell(190, 6, "Active Basal Programs & SmartBolus Settings", ln=True)
    pdf.set_font("Arial", '', 9)
    pdf.cell(95, 6, "Max Basal Rate: 5.0 U/hr", border=1)
    pdf.cell(95, 6, "Temporary Basal: Enabled", border=1, ln=True)
    pdf.cell(95, 6, f"Target Glucose: {patient['target_glucose']} mg/dL", border=1)
    pdf.cell(95, 6, f"IC Ratio: 1 U : {patient['ic_ratio']} g", border=1, ln=True)
    
    pdf.output(filename)
    if os.path.exists(agp_img): os.remove(agp_img)
    if os.path.exists(daily_img): os.remove(daily_img)

# 4. توليد بيانات الـ 20 مريضاً بأسماء حقيقية وتنوع أرقام (هبوط، ارتفاع، استقرار) بدون أي علامات خارجية
patients_data = []
names_pool = [
    "Sara Al-Otaibi", "Mohammed Al-Shammari", "Fatima Al-Qahtani", "Abdullah Al-Dosari",
    "Nouf Al-Anzi", "Fahad Al-Harbi", "Reem Al-Ghamdi", "Khalid Al-Subaie",
    "Layan Al-Mutairi", "Nasser Al-Shehri", "Ahad Al-Bogami", "Turki Al-Zahrani",
    "Ghada Al-Tmimi", "Sultan Al-Oufi", "Joud Al-Asmari", "Yousef Al-Malki",
    "Mayar Al-Sherif", "Badr Al-Khaldi", "Hissah Al-Dossari", "Ziyad Al-Thobaiti"
]

for i in range(1, 21):
    # التنويع للأرقام (بعضهم عنده هبوط عالي، بعضهم ارتفاع عالي، وبعضهم مستقر)
    if i % 4 == 1: # حالة هبوط متطرفة في الأرقام
        v_high, high, tir, low, v_low, avg_g, gmi, cv, sd = 0.5, 2.0, 48.0, 16.0, 33.5, 94, 5.6, 46.0, 50.0
    elif i % 4 == 2: # حالة ارتفاع واضحة في الأرقام
        v_high, high, tir, low, v_low, avg_g, gmi, cv, sd = 25.0, 40.0, 30.0, 3.0, 2.0, 235, 9.0, 40.0, 65.0
    elif i % 4 == 3: # حالة تذبذب (Unstable) في الأرقام
        v_high, high, tir, low, v_low, avg_g, gmi, cv, sd = 12.0, 22.0, 45.0, 11.0, 10.0, 168, 7.4, 50.0, 58.0
    else: # حالة مستقر (Stable)
        v_high, high, tir, low, v_low, avg_g, gmi, cv, sd = 0.1, 7.5, 84.0, 5.0, 3.4, 114, 6.0, 30.0, 34.0

    patients_data.append({
        "id": i, 
        "name": names_pool[i-1], 
        "dob": "12/05/2002", "age": 24, "report_date": "30/08/2026", "date_range": "01/08/2026-30/08/2026",
        "very_high": v_high, "high": high, "tir": tir, "low": low, "very_low": v_low,
        "avg_glucose": avg_g, "gmi": gmi, "cv": cv, "sd": sd, "device": "Omnipod 5 & Dexcom G7",
        "auto_mode": "65%", "target_glucose": 110, "ic_ratio": 10
    })

for patient_info in patients_data:
    out_name = f"report_patient_{patient_info['id']}.pdf"
    create_patient_pdf(patient_info, out_name)
    print(f"Generated clean clinical report: {out_name}")

print("\nDone! All 20 clinical reports generated cleanly with pure numbers and charts.")