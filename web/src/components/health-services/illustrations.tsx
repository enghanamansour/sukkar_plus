import type { TileArt } from './services';

/**
 * Original flat illustrations for Health File tiles, drawn in the app palette.
 * They sit at the bottom of each tile like the reference artwork. Decorative only.
 */
const NAVY = '#123b6a';
const BLUE = '#1a6fb0';
const SKY = '#7fc0ea';
const PALE = '#d9ecf8';
const SKIN = '#f2c7a5';
const WHITE = '#ffffff';

export function TileIllustration({ art }: { art: TileArt }) {
  return (
    <svg className="tile-art" viewBox="0 0 100 58" aria-hidden focusable="false">
      {ART[art]}
    </svg>
  );
}

const ART: Record<TileArt, JSX.Element> = {
  careTeam: (
    <g>
      <ellipse cx="50" cy="56" rx="46" ry="3" fill={PALE} />
      {/* doctor */}
      <circle cx="40" cy="16" r="7" fill={SKIN} />
      <path d="M33 13c0-6 14-6 14 0v-2c0-5-14-5-14 2Z" fill={NAVY} />
      <path d="M27 56V34c0-7 6-11 13-11s13 4 13 11v22Z" fill={WHITE} stroke={NAVY} strokeWidth="1.4" />
      <path d="M40 23v33" stroke={NAVY} strokeWidth="1.2" />
      <path d="M34 26c0 6 2 9 5 10" fill="none" stroke={BLUE} strokeWidth="1.4" />
      <circle cx="39" cy="37" r="1.8" fill={BLUE} />
      {/* patient */}
      <circle cx="70" cy="26" r="6" fill={SKIN} />
      <path d="M64 24c0-5 12-5 12 0v-3c0-4-12-4-12 3Z" fill="#2b2b3a" />
      <path d="M60 56V42c0-6 4-9 10-9s10 3 10 9v14Z" fill={BLUE} />
      <rect x="66" y="28" width="8" height="4" rx="1.5" fill={SKY} />
      {/* small figure on the edge */}
      <circle cx="12" cy="34" r="5" fill={SKIN} />
      <path d="M5 56V46c0-5 3-7 7-7s7 2 7 7v10Z" fill={NAVY} />
    </g>
  ),
  record: (
    <g>
      <rect x="18" y="12" width="64" height="46" rx="3" fill={WHITE} stroke={NAVY} strokeWidth="2.4" />
      <rect x="40" y="7" width="20" height="9" rx="2" fill={NAVY} />
      <rect x="28" y="24" width="44" height="3" rx="1.5" fill={PALE} />
      <rect x="28" y="31" width="30" height="3" rx="1.5" fill={PALE} />
      <circle cx="40" cy="45" r="3.4" fill={BLUE} />
      <path d="M34 54c0-4 3-6 6-6s6 2 6 6Z" fill={BLUE} />
      <rect x="52" y="44" width="20" height="3" rx="1.5" fill={SKY} />
    </g>
  ),
  pills: (
    <g>
      <rect x="10" y="20" width="12" height="26" rx="6" fill={SKY} transform="rotate(-35 16 33)" />
      <rect x="10" y="33" width="12" height="13" rx="0" fill={BLUE} transform="rotate(-35 16 33)" />
      <circle cx="34" cy="48" r="5" fill={NAVY} />
      <circle cx="46" cy="40" r="4" fill={BLUE} />
      <circle cx="28" cy="34" r="3" fill={SKY} />
      <circle cx="60" cy="50" r="6" fill={PALE} stroke={SKY} strokeWidth="1.2" />
      <circle cx="80" cy="42" r="9" fill="none" stroke={PALE} strokeWidth="3" />
      <path d="M87 49l7 7" stroke={PALE} strokeWidth="3.5" strokeLinecap="round" />
    </g>
  ),
  glucose: (
    <g>
      <ellipse cx="50" cy="56" rx="44" ry="3" fill={PALE} />
      {/* meter */}
      <rect x="22" y="8" width="34" height="48" rx="7" fill={WHITE} stroke={NAVY} strokeWidth="2.2" />
      <rect x="27" y="14" width="24" height="16" rx="2.5" fill={PALE} />
      <path d="M30 26l5-5 4 3 5-6 4 4" fill="none" stroke={BLUE} strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" />
      <circle cx="33" cy="42" r="3.2" fill={SKY} />
      <circle cx="45" cy="42" r="3.2" fill={BLUE} />
      <rect x="35" y="2" width="8" height="8" rx="1" fill={SKY} />
      {/* blood drop */}
      <path d="M76 18c5 7 8 12 8 16a8 8 0 0 1-16 0c0-4 3-9 8-16Z" fill="#e5546a" />
      <path d="M73 34a3 3 0 0 0 3 3" fill="none" stroke={WHITE} strokeWidth="1.6" strokeLinecap="round" />
      {/* report sheet */}
      <rect x="62" y="44" width="26" height="12" rx="2" fill={WHITE} stroke={SKY} strokeWidth="1.4" />
      <rect x="66" y="48" width="14" height="2" rx="1" fill={SKY} />
    </g>
  ),
  lab: (
    <g>
      <path d="M40 6h14M43 6v18L30 50a4 4 0 0 0 4 6h26a4 4 0 0 0 4-6L51 24V6" fill={WHITE} stroke={NAVY} strokeWidth="2.2" strokeLinejoin="round" />
      <path d="M36 40h22l4 10a3 3 0 0 1-3 4H35a3 3 0 0 1-3-4Z" fill={SKY} />
      <circle cx="44" cy="46" r="2" fill={WHITE} />
      <rect x="70" y="22" width="8" height="34" rx="4" fill={PALE} stroke={BLUE} strokeWidth="1.4" />
      <rect x="70" y="40" width="8" height="16" rx="4" fill={BLUE} />
    </g>
  ),
  vaccine: (
    <g transform="rotate(-30 50 32)">
      <rect x="26" y="26" width="40" height="12" rx="2" fill={WHITE} stroke={NAVY} strokeWidth="2" />
      <rect x="28" y="28" width="22" height="8" fill={SKY} />
      <path d="M66 32h12M78 26v12M18 32h8M14 32h-6" stroke={NAVY} strokeWidth="2.2" strokeLinecap="round" />
      <path d="M8 32l-6 0" stroke={BLUE} strokeWidth="1.2" />
    </g>
  ),
  allergy: (
    <g>
      <path d="M50 6l22 8v14c0 14-9 23-22 28-13-5-22-14-22-28V14Z" fill={PALE} stroke={NAVY} strokeWidth="2" />
      <path d="M50 20v14" stroke={BLUE} strokeWidth="3.5" strokeLinecap="round" />
      <circle cx="50" cy="42" r="2.4" fill={BLUE} />
    </g>
  ),
  vitals: (
    <g>
      <path d="M50 54S20 38 20 20a12 12 0 0 1 30-6 12 12 0 0 1 30 6c0 18-30 34-30 34Z" fill={PALE} stroke={NAVY} strokeWidth="2" />
      <path d="M22 32h16l5-10 7 20 5-10h23" fill="none" stroke={BLUE} strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round" />
    </g>
  ),
  referral: (
    <g>
      <rect x="14" y="14" width="30" height="40" rx="3" fill={WHITE} stroke={NAVY} strokeWidth="2" />
      <rect x="56" y="14" width="30" height="40" rx="3" fill={PALE} stroke={BLUE} strokeWidth="2" />
      <path d="M38 34h22m-6-6 6 6-6 6" fill="none" stroke={BLUE} strokeWidth="2.6" strokeLinecap="round" strokeLinejoin="round" />
      <rect x="19" y="22" width="16" height="2.5" rx="1" fill={SKY} />
      <rect x="61" y="22" width="16" height="2.5" rx="1" fill={SKY} />
    </g>
  ),
};
