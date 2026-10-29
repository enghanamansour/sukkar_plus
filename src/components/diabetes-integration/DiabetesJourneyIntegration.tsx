import type { Direction, Language } from '../../types';
import { useLanguage } from '../../i18n';
import { DiabetesJourneyPlaceholder } from './DiabetesJourneyPlaceholder';
import { diabetesJourneyComponent, diabetesJourneyEmbedUrl } from './mount';

export interface DiabetesJourneyIntegrationProps {
  language: Language;
  direction: Direction;
  basePath: string;
  onExit: () => void;
}

/**
 * Integration boundary between the Sehhaty-inspired shell and the separately built
 * diabetes-care product.
 *
 * Responsibilities (and nothing more):
 *  - provide a content area inside the app shell (bottom nav + back header stay outside it);
 *  - set `lang`/`dir` on that area so RTL/LTR is correct for whatever is mounted;
 *  - pass language, direction, basePath and an exit callback to the mounted feature;
 *  - fall back to a clearly labelled placeholder when nothing is mounted.
 *
 * It intentionally makes no assumptions about the other team's components, data or APIs.
 */
export function DiabetesJourneyIntegration({ language, direction, basePath, onExit }: DiabetesJourneyIntegrationProps) {
  const { t } = useLanguage();
  const Feature = diabetesJourneyComponent;

  let content;
  let mode: 'component' | 'embed' | 'placeholder';
  if (Feature) {
    mode = 'component';
    content = <Feature language={language} direction={direction} basePath={basePath} onExit={onExit} />;
  } else if (diabetesJourneyEmbedUrl) {
    mode = 'embed';
    const url = new URL(diabetesJourneyEmbedUrl, window.location.href);
    url.searchParams.set('lang', language);
    url.searchParams.set('dir', direction);
    content = <iframe key={url.toString()} className="dj-frame" src={url.toString()} title={t.diabetes.frameTitle} />;
  } else {
    mode = 'placeholder';
    content = <DiabetesJourneyPlaceholder onExit={onExit} />;
  }

  return (
    <section className={`dj-host dj-host--${mode}`} lang={language} dir={direction} data-integration="diabetes-journey" data-mode={mode}>
      {content}
    </section>
  );
}
