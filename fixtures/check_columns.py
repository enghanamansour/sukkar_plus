import pandas as pd

# قراءة الملف بالاسم الصحيح الذي ظهر في القائمة
df = pd.read_excel("DC.xlsx.xlsx")

# طباعة أسماء الأعمدة الموجودة في الملف
print("أسماء الأعمدة في ملف DC.xlsx.xlsx هي:")
print(df.columns)