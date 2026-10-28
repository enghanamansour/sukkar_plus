import type { ButtonHTMLAttributes, ReactNode } from 'react';

type Variant = 'primary' | 'secondary' | 'ghost' | 'danger' | 'link';

interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: Variant;
  block?: boolean;
  size?: 'md' | 'lg';
  icon?: ReactNode;
  iconEnd?: ReactNode;
}

export function Button({ variant = 'primary', block, size = 'md', icon, iconEnd, className, children, type = 'button', ...rest }: ButtonProps) {
  const classes = ['btn', `btn--${variant}`, `btn--${size}`, block ? 'btn--block' : '', className ?? ''].filter(Boolean).join(' ');
  return (
    <button type={type} className={classes} {...rest}>
      {icon}
      {children && <span>{children}</span>}
      {iconEnd}
    </button>
  );
}
