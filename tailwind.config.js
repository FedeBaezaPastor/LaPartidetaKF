/** @type {import('tailwindcss').Config} */
export default {
  darkMode: 'class',
  content: ['./index.html', './src/**/*.{js,ts,jsx,tsx}'],
  theme: {
    extend: {
      colors: {
        app: 'var(--app)',
        card: 'var(--card)',
        'card-2': 'var(--card-2)',
        line: 'var(--line)',
        'line-2': 'var(--line-2)',
        ink: 'var(--ink)',
        'ink-2': 'var(--ink-2)',
        'ink-3': 'var(--ink-3)',
        'ink-4': 'var(--ink-4)',
        title: 'var(--title)',
        accent: 'var(--accent)',
        'accent-hover': 'var(--accent-hover)',
        'accent-deep': 'var(--accent-deep)',
        'accent-soft': 'var(--accent-soft)',
        'accent-ring': 'var(--accent-ring)',
        'accent-ink': 'var(--accent-ink)',
        'on-accent': 'var(--on-accent)',
        'on-deep': 'var(--on-deep)',
        neutral: 'var(--neutral)',
        'neutral-hover': 'var(--neutral-hover)',
        'neutral-ink': 'var(--neutral-ink)',
      },
      boxShadow: {
        card: 'var(--shadow-card)',
        soft: 'var(--shadow-soft)',
      },
    },
  },
  plugins: [],
};
