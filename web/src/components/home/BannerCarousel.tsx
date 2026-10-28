import { useRef, useState } from 'react';
import { Link } from 'react-router-dom';
import { HeartPulse, Footprints, Stethoscope } from 'lucide-react';
import type { ReactNode } from 'react';
import { format, useLanguage } from '../../i18n';
import { serviceRoute } from '../../routes';

type SlideKey = 'checkup' | 'screening' | 'walk';

const slides: { key: SlideKey; tone: string; icon: ReactNode; route: string }[] = [
  { key: 'checkup', tone: 'teal', icon: <HeartPulse size={34} strokeWidth={1.6} aria-hidden />, route: serviceRoute('home', 'checkup') },
  { key: 'screening', tone: 'rose', icon: <Stethoscope size={34} strokeWidth={1.6} aria-hidden />, route: serviceRoute('home', 'screening') },
  { key: 'walk', tone: 'green', icon: <Footprints size={34} strokeWidth={1.6} aria-hidden />, route: serviceRoute('wellness', 'walkCampaign') },
];

/** Horizontally swipeable campaign banners with pagination dots (scroll-snap, no autoplay). */
export function BannerCarousel() {
  const { t, dir } = useLanguage();
  const trackRef = useRef<HTMLDivElement>(null);
  const [index, setIndex] = useState(0);

  const onScroll = () => {
    const el = trackRef.current;
    if (!el) return;
    const i = Math.round(Math.abs(el.scrollLeft) / el.clientWidth);
    setIndex(Math.min(slides.length - 1, Math.max(0, i)));
  };

  const goTo = (i: number) => {
    const el = trackRef.current;
    if (!el) return;
    el.scrollTo({ left: (dir === 'rtl' ? -1 : 1) * i * el.clientWidth, behavior: 'smooth' });
  };

  return (
    <section className="carousel" aria-roledescription="carousel" aria-label={t.home.carouselLabel}>
      <div className="carousel__track" ref={trackRef} onScroll={onScroll}>
        {slides.map((s, i) => {
          const copy = t.home.slides[s.key];
          return (
            <Link
              key={s.key}
              to={s.route}
              className={`carousel__slide carousel__slide--${s.tone}`}
              aria-roledescription="slide"
              aria-label={`${format(t.common.slide, { n: i + 1 })}: ${copy.title}`}
            >
              <div className="carousel__text">
                <span className="carousel__tag">{copy.tag}</span>
                <span className="carousel__title">{copy.title}</span>
                <span className="carousel__body">{copy.body}</span>
              </div>
              <div className="carousel__cta">
                {s.icon}
                <span>{copy.cta}</span>
              </div>
            </Link>
          );
        })}
      </div>
      <div className="carousel__dots">
        {slides.map((s, i) => (
          <button
            key={s.key}
            type="button"
            className={`carousel__dot ${i === index ? 'is-active' : ''}`}
            aria-label={format(t.common.slide, { n: i + 1 })}
            aria-current={i === index}
            onClick={() => goTo(i)}
          />
        ))}
      </div>
    </section>
  );
}
