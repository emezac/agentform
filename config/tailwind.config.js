const defaultTheme = require('tailwindcss/defaultTheme')

module.exports = {
  content: [
    './public/*.html',
    './app/helpers/**/*.rb',
    './app/javascript/**/*.js',
    './app/views/**/*.{erb,haml,html,slim}'
  ],
  theme: {
    extend: {
      fontFamily: {
        sans: ['Inter var', ...defaultTheme.fontFamily.sans],
      },
      keyframes: {
        'slide-up-elegant': {
          '0%': { 
            opacity: '0', 
            transform: 'translateY(40px) scale(0.95)',
            filter: 'blur(2px)'
          },
          '50%': { 
            opacity: '0.7', 
            transform: 'translateY(20px) scale(0.98)',
            filter: 'blur(1px)'
          },
          '100%': { 
            opacity: '1', 
            transform: 'translateY(0) scale(1)',
            filter: 'blur(0px)'
          }
        },
        'slide-down-elegant': {
          '0%': { 
            opacity: '1', 
            transform: 'translateY(0) scale(1)',
            filter: 'blur(0px)'
          },
          '50%': { 
            opacity: '0.3', 
            transform: 'translateY(-20px) scale(0.98)',
            filter: 'blur(1px)'
          },
          '100%': { 
            opacity: '0', 
            transform: 'translateY(-40px) scale(0.95)',
            filter: 'blur(2px)'
          }
        },
        'fade-in-up': {
          '0%': { 
            opacity: '0', 
            transform: 'translateY(20px)' 
          },
          '100%': { 
            opacity: '1', 
            transform: 'translateY(0)' 
          }
        },
        'progress-fill': {
          '0%': { width: '0%' },
          '100%': { width: 'var(--progress-width)' }
        },
        'gentle-bounce': {
          '0%, 100%': { transform: 'translateY(0)' },
          '50%': { transform: 'translateY(-2px)' }
        },
        'shimmer': {
          '0%': { transform: 'translateX(-100%)' },
          '100%': { transform: 'translateX(100%)' }
        }
      },
      animation: {
        'slide-up-elegant': 'slide-up-elegant 0.6s cubic-bezier(0.16, 1, 0.3, 1) forwards',
        'slide-down-elegant': 'slide-down-elegant 0.4s cubic-bezier(0.4, 0, 0.6, 1) forwards',
        'fade-in-up': 'fade-in-up 0.5s cubic-bezier(0.16, 1, 0.3, 1) forwards',
        'progress-fill': 'progress-fill 0.8s cubic-bezier(0.16, 1, 0.3, 1) forwards',
        'gentle-bounce': 'gentle-bounce 2s ease-in-out infinite',
        'shimmer': 'shimmer 2s infinite'
      },
      transitionTimingFunction: {
        'elegant': 'cubic-bezier(0.16, 1, 0.3, 1)',
        'smooth': 'cubic-bezier(0.4, 0, 0.2, 1)'
      },
      backdropBlur: {
        xs: '2px'
      }
    },
  },
  plugins: [
    require('@tailwindcss/forms'),
    require('@tailwindcss/aspect-ratio'),
    require('@tailwindcss/typography'),
  ]
}
