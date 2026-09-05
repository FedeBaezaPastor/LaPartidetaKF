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
      className={`inline-flex items-center gap-0.5 bg-card border border-line rounded-full p-1 shadow-soft transition-colors ${className}`}
    >
      <span className={`rounded-full p-1.5 transition-colors ${!isDark ? 'bg-accent text-on-accent' : 'text-ink-3'}`}>
        <Sun size={16} />
      </span>
      <span className={`rounded-full p-1.5 transition-colors ${isDark ? 'bg-accent text-on-accent' : 'text-ink-3'}`}>
        <Moon size={16} />
      </span>
    </button>
  );
};
