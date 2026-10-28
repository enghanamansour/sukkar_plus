import pandas as pd
import numpy as np

# 1. قراءة ملف الإكسل بالاسم الصحيح
excel_path = "DC.xlsx.xlsx"
df_labs = pd.read_excel(excel_path)

# 2. تجهيز بيانات المرضى الـ 20 مع قيم GMI/HbA1c المقابلة لمتوسطات السكر لديهم
names_pool = [
    "Sara Al-Otaibi", "Mohammed Al-Shammari", "Fatima Al-Qahtani", "Abdullah Al-Dosari",
    "Nouf Al-Anzi", "Fahad Al-Harbi", "Reem Al-Ghamdi", "Khalid Al-Subaie",
    "Layan Al-Mutairi", "Nasser Al-Shehri", "Ahad Al-Bogami", "Turki Al-Zahrani",
    "Ghada Al-Tmimi", "Sultan Al-Oufi", "Joud Al-Asmari", "Yousef Al-Malki",
    "Mayar Al-Sherif", "Badr Al-Khaldi", "Hissah Al-Dossari", "Ziyad Al-Thobaiti"
]

patients_data = []
for i in range(1, 21):
    # ربط تقديري لقيمة الـ HbA1c المقابلة لحالة المريض
    if i % 4 == 1: hba1c_target = 5.6   # هبوط/تحكم ممتاز
    elif i % 4 == 2: hba1c_target = 9.2  # ارتفاع عالي
    elif i % 4 == 3: hba1c_target = 7.6  # غير مستقر
    else: hba1c_target = 6.0           # مستقر

    patients_data.append({
        "patient_id": i,
        "name": names_pool[i-1],
        "target_hba1c": hba1c_target
    })

df_patients = pd.DataFrame(patients_data)

# 3. المطابقة الرياضية بناءً على عمود 'HbA1C Level' الحقيقي في ملف الإكسل
target_column = 'HbA1C Level'

matched_results = []
for _, patient in df_patients.iterrows():
    # البحث عن السطر الأقرب قيمة في تحليل الـ HbA1c
    idx_closest = (df_labs[target_column] - patient['target_hba1c']).abs().idxmin()
    
    matched_row = df_labs.loc[idx_closest].copy()
    matched_row['patient_id'] = patient['patient_id']
    matched_row['patient_name'] = patient['name']
    
    matched_results.append(matched_row)

df_final = pd.DataFrame(matched_results)

print("تم ربط ملف تحاليل الدم DC.xlsx بالمرضى بنجاح تام بناءً على عمود HbA1C Level!")
print(df_final[['patient_id', 'patient_name', 'HbA1C Level']])

# حفظ النتائج المربوطة في ملف إكسل نهائي
df_final.to_excel("final_patients_with_DC_labs.xlsx", index=False)
print("\nتم حفظ الملف النهائي باسم: final_patients_with_DC_labs.xlsx")