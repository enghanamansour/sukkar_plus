/** Shared frontend types for the Sehhaty-inspired mockup. */

export type Language = 'ar' | 'en';
export type Direction = 'rtl' | 'ltr';

/** Text that lives in mock data (not UI chrome) and therefore needs both languages inline. */
export interface LocalizedText {
  ar: string;
  en: string;
}

export type AppointmentStatus = 'upcoming' | 'previous';
export type VisitType = 'inPerson' | 'virtual';

export interface Appointment {
  id: string;
  clinic: LocalizedText;
  visitType: VisitType;
  facility: LocalizedText;
  /** ISO date-time string (synthetic). */
  dateTime: string;
  status: AppointmentStatus;
}

export interface PatientProfile {
  id: string;
  initial: LocalizedText;
  name: LocalizedText;
  healthId: string;
  dateOfBirth: string;
  gender: LocalizedText;
  bloodType: string;
  nationality: LocalizedText;
  relation?: LocalizedText;
}

export interface NotificationItem {
  id: string;
  title: LocalizedText;
  body: LocalizedText;
  /** ISO date-time string (synthetic). */
  createdAt: string;
  read: boolean;
  kind: 'appointment' | 'prescription' | 'result' | 'general';
}
