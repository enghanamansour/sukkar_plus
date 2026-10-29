import { useState } from 'react';
import { BedSingle, Check, ClipboardList, CircleHelp, CreditCard, FileCheck2, Languages, Share2, Users } from 'lucide-react';
import { useLanguage } from '../i18n';
import { useAppState } from '../state/AppState';
import { patients } from '../data/mockData';
import { serviceRoute } from '../routes';
import { PageHeader } from '../components/layout/PageHeader';
import { ProfileCard } from '../components/profile/ProfileCard';
import { DigitalTwinBanner } from '../components/profile/DigitalTwinBanner';
import { ListSection } from '../components/profile/ListSection';
import { HealthFileGrid } from '../components/health-services/HealthFileGrid';
import { Button, Dialog, LanguageSwitch } from '../components/ui';

/**
 * ملفي — My Profile.
 * Hosts the only entry point to "عضيد" (inside HealthFileGrid).
 */
export function MyProfilePage() {
  const { t, l } = useLanguage();
  const { activeProfile, setActiveProfileId, showToast } = useAppState();
  const [switcherOpen, setSwitcherOpen] = useState(false);
  const [shareOpen, setShareOpen] = useState(false);

  const copyId = async () => {
    try {
      await navigator.clipboard.writeText(activeProfile.healthId);
      showToast(t.common.copied);
    } catch {
      showToast(t.common.copyFailed);
    }
    setShareOpen(false);
  };

  return (
    <div className="page page--profile">
      <PageHeader
        title={t.profile.title}
        onTitleClick={() => setSwitcherOpen(true)}
        titleExpanded={switcherOpen}
        titleButtonLabel={t.profile.switchProfile}
        end={
          <button type="button" className="header-link" onClick={() => setShareOpen(true)}>
            <Share2 size={16} aria-hidden />
            {t.common.share}
          </button>
        }
      />
      <div className="page__body">
        <ProfileCard />
        <DigitalTwinBanner />
        <HealthFileGrid />

        <ListSection
          title={t.profile.reportsDocs}
          items={[
            { key: 'sickLeaves', label: t.profile.sickLeaves, icon: <BedSingle size={20} aria-hidden />, to: serviceRoute('profile', 'sickLeaves') },
            { key: 'medicalReports', label: t.profile.medicalReports, icon: <ClipboardList size={20} aria-hidden />, to: serviceRoute('profile', 'medicalReports') },
          ]}
        />

        <ListSection
          title={t.profile.other}
          items={[
            { key: 'dependents', label: t.profile.dependents, icon: <Users size={20} aria-hidden />, to: serviceRoute('profile', 'dependents') },
            { key: 'questionnaires', label: t.profile.questionnaires, icon: <CircleHelp size={20} aria-hidden />, to: serviceRoute('profile', 'questionnaires') },
            { key: 'myCard', label: t.profile.myCard, icon: <CreditCard size={20} aria-hidden />, to: serviceRoute('profile', 'myCard') },
            { key: 'insurance', label: t.profile.insuranceApprovals, icon: <FileCheck2 size={20} aria-hidden />, to: serviceRoute('profile', 'insurance') },
          ]}
        />

        <ListSection
          title={t.profile.settings}
          items={[{ key: 'language', label: t.language.label, icon: <Languages size={20} aria-hidden />, trailing: <LanguageSwitch variant="segmented" /> }]}
        />

        <section className="partners">
          <h2 className="partners__title">{t.profile.partners}</h2>
          <p>{t.profile.partnersBody}</p>
        </section>
      </div>

      <Dialog open={switcherOpen} onClose={() => setSwitcherOpen(false)} title={t.profile.switchProfile}>
        <ul className="choice-list">
          {patients.map((p) => (
            <li key={p.id}>
              <button
                type="button"
                className={`choice ${activeProfile.id === p.id ? 'is-active' : ''}`}
                aria-pressed={activeProfile.id === p.id}
                onClick={() => {
                  setActiveProfileId(p.id);
                  setSwitcherOpen(false);
                }}
              >
                <span className="choice__avatar" aria-hidden>{l(p.initial)}</span>
                <span className="choice__text">
                  <span>{l(p.name)}</span>
                  <small>{p.relation ? l(p.relation) : t.profile.self}</small>
                </span>
                {activeProfile.id === p.id && <Check size={18} aria-hidden />}
              </button>
            </li>
          ))}
        </ul>
      </Dialog>

      <Dialog
        open={shareOpen}
        onClose={() => setShareOpen(false)}
        title={t.profile.shareTitle}
        actions={
          <>
            <Button variant="secondary" onClick={() => setShareOpen(false)}>{t.common.cancel}</Button>
            <Button onClick={copyId}>{t.profile.copyHealthId}</Button>
          </>
        }
      >
        <p>{t.profile.shareBody}</p>
        <p className="share-id"><bdi>{activeProfile.healthId}</bdi></p>
      </Dialog>
    </div>
  );
}
