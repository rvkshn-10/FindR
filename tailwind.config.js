/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    './pages/**/*.{js,ts,jsx,tsx,mdx}',
    './components/**/*.{js,ts,jsx,tsx,mdx}',
    './app/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  theme: {
    extend: {
      colors: {
        primary: {
          50: '#faf9f7',
          100: '#f5f3f0',
          200: '#ebe7e0',
          300: '#d6cfc1',
          400: '#b8a892',
          500: '#9d8b73',
          600: '#7d6d5a',
          700: '#65584a',
          800: '#534a3f',
          900: '#463f37',
          950: '#25221d',
        },
        cream: {
          50: '#fefdfb',
          100: '#fefbf5',
          200: '#fdf6e8',
          300: '#faedd3',
          400: '#f6e0b5',
          500: '#f0cf8f',
          600: '#e7b866',
          700: '#d99f3f',
          800: '#b8822f',
          900: '#986a29',
        },
      },
      fontFamily: {
        serif: ['Georgia', 'serif'],
      },
    },
  },
  plugins: [],
}
