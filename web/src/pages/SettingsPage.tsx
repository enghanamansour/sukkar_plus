import { Languages, MoonStar } from 'lucide-react';
import { useLanguage } from '../i18n';
import { ROUTES } from '../routes';
import { BackHeader } from '../components/layout/PageHeader';
import { ListSection } from '../components/profile/ListSection';
import { LanguageSwitch, ThemeSwitch } from '../components/ui';

/** الإعدادات — opened from the "المزيد" panel. Hosts the language choice. */
export function SettingsPage() {
  const { t } = useLanguage();
  return (
    <div className="page">
      <BackHeader title={t.menu.settings} backTo={ROUTES.home} />
      <div className="page__body">
        <ListSection
          title={t.theme.label}
          items={[{ key: 'theme', label: t.theme.label, icon: <MoonStar size={20} aria-hidden />, trailing: <ThemeSwitch /> }]}
        />
        <ListSection
          title={t.language.label}
          items={[{ key: 'language', label: t.language.appLanguage, icon: <Languages size={20} aria-hidden />, trailing: <LanguageSwitch variant="segmented" /> }]}
        />
      </div>
    </div>
  );
}
