/**
 * Synthetic demonstration data. All names, IDs and records are fictional.
 * Kept separate from UI components so it can be swapped for real data sources later.
 */
import type { Appointment, LocalizedText, NotificationItem, PatientProfile } from '../types';

export const facilityName: LocalizedText = {
  ar: 'مركز صحي الروضة',
  en: 'AlRawdah Health Center',
};

export const patients: PatientProfile[] = [
  {
    id: 'self',
    initial: { ar: 'ن', en: 'N' },
    name: { ar: 'نورة عبدالله السالم', en: 'NOURA ABDULLAH ALSALEM' },
    healthId: '1098765432',
    dateOfBirth: '1996-03-14',
    gender: { ar: 'أنثى', en: 'Female' },
    bloodType: 'O+',
    nationality: { ar: 'سعودية', en: 'Saudi' },
  },
  {
    id: 'dep-1',
    initial: { ar: 'ف', en: 'F' },
    name: { ar: 'فهد عبدالله السالم', en: 'FAHAD ABDULLAH ALSALEM' },
    healthId: '1123456789',
    dateOfBirth: '2012-09-02',
    gender: { ar: 'ذكر', en: 'Male' },
    bloodType: 'A+',
    nationality: { ar: 'سعودي', en: 'Saudi' },
    relation: { ar: 'ابن', en: 'Son' },
  },
];

/** First name used in the home greeting. */
export const greetingName: LocalizedText = { ar: 'نورة', en: 'NOURA' };

export const clinicOptions: { id: string; name: LocalizedText }[] = [
  { id: 'family', name: { ar: 'عيادة طب الأسرة', en: 'Family Medicine Clinic' } },
  { id: 'dental', name: { ar: 'عيادة الأسنان', en: 'Dental Clinic' } },
  { id: 'eye', name: { ar: 'عيادة العيون', en: 'Ophthalmology Clinic' } },
  { id: 'internal', name: { ar: 'عيادة الباطنية', en: 'Internal Medicine Clinic' } },
  { id: 'derma', name: { ar: 'عيادة الجلدية', en: 'Dermatology Clinic' } },
];

export const timeSlots = ['08:00', '09:30', '11:00', '13:00', '16:00', '19:30', '22:00'];

export const initialAppointments: Appointment[] = [
  {
    id: 'apt-1',
    clinic: clinicOptions[0].name,
    visitType: 'inPerson',
    facility: facilityName,
    dateTime: '2026-11-04T10:00:00',
    status: 'upcoming',
  },
  {
    id: 'apt-2',
    clinic: clinicOptions[1].name,
    visitType: 'virtual',
    facility: facilityName,
    dateTime: '2026-11-18T16:00:00',
    status: 'upcoming',
  },
  {
    id: 'apt-3',
    clinic: clinicOptions[3].name,
    visitType: 'inPerson',
    facility: facilityName,
    dateTime: '2026-09-21T09:30:00',
    status: 'previous',
  },
  {
    id: 'apt-4',
    clinic: clinicOptions[0].name,
    visitType: 'inPerson',
    facility: facilityName,
    dateTime: '2026-07-06T11:00:00',
    status: 'previous',
  },
];

export const dailyActivity = {
  steps: 3741,
  defaultTarget: 8000,
  durationMinutes: 0,
  distanceKm: 2.4,
  calories: 0,
};

export const initialNotifications: NotificationItem[] = [
  {
    id: 'n-1',
    kind: 'appointment',
    title: { ar: 'تذكير بموعد', en: 'Appointment reminder' },
    body: {
      ar: 'لديك موعد في عيادة طب الأسرة يوم 4 نوفمبر الساعة 10:00 ص.',
      en: 'You have a Family Medicine appointment on 4 November at 10:00 AM.',
    },
    createdAt: '2026-10-28T09:12:00',
    read: false,
  },
  {
    id: 'n-2',
    kind: 'prescription',
    title: { ar: 'وصفة جديدة', en: 'New prescription' },
    body: { ar: 'تمت إضافة وصفة جديدة إلى ملفك.', en: 'A new prescription was added to your file.' },
    createdAt: '2026-10-26T14:40:00',
    read: false,
  },
  {
    id: 'n-3',
    kind: 'result',
    title: { ar: 'نتائج الفحوصات', en: 'Lab results' },
    body: { ar: 'نتائج فحوصاتك الأخيرة متاحة الآن.', en: 'Your latest lab results are now available.' },
    createdAt: '2026-10-20T08:05:00',
    read: true,
  },
  {
    id: 'n-4',
    kind: 'general',
    title: { ar: 'حملة امشِ 30', en: 'Walk 30 campaign' },
    body: { ar: 'انضم إلى تحدي الخطوات هذا الشهر.', en: 'Join this month’s step challenge.' },
    createdAt: '2026-10-15T18:30:00',
    read: true,
  },
];
