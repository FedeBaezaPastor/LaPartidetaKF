// src/components/ThemeToggle.tsx
import React from 'react';
import { Sun, Moon } from 'lucide-react';
import { useTheme } from '../hooks/useTheme';

interface ThemeToggleProps {
  className?: string;
}

export const ThemeToggle: React.FC<ThemeToggleProps> = ({ className = '' }) => {
  const { isDark, toggle } = useTheme();

  return (
    <button
      type="button"
      onClick={toggle}
      title={isDark ? 'Cambiar a tema claro' : 'Cambiar a tema oscuro'}
      aria-label={isDark ? 'Cambiar a tema claro' : 'Cambiar a tema oscuro'}
      className={`inline-flex h-10 w-10 items-center justify-center rounded-full border border-line bg-card text-accent-ink shadow-soft transition-all hover:bg-card-2 active:scale-95 ${className}`}
    >
      {isDark ? <Sun size={19} /> : <Moon size={19} />}
    </button>
  );
};
