/** @type {import('tailwindcss').Config} */
export default {
	darkMode: 'class',
	content: ['./src/**/*.{html,js,svelte,ts}'],
	theme: {
		extend: {
			colors: {
				primary: '#895100',
				'primary-container': '#FF9F1C',
				'primary-fixed': '#FFDCBC',
				'primary-fixed-dim': '#FFB86B',
				'on-primary': '#FFFFFF',
				'on-primary-container': '#683C00',
				'on-primary-fixed': '#2C1700',
				'on-primary-fixed-variant': '#683D00',

				secondary: '#835401',
				'secondary-container': '#FDBD68',
				'secondary-fixed': '#FFDDB5',
				'secondary-fixed-dim': '#FABB65',
				'on-secondary': '#FFFFFF',
				'on-secondary-container': '#764B00',
				'on-secondary-fixed': '#2A1800',
				'on-secondary-fixed-variant': '#643F00',

				tertiary: '#006A62',
				'tertiary-container': '#36C9BB',
				'tertiary-fixed': '#70F8E8',
				'tertiary-fixed-dim': '#4FDBCC',
				'on-tertiary': '#FFFFFF',
				'on-tertiary-container': '#005049',
				'on-tertiary-fixed': '#00201D',
				'on-tertiary-fixed-variant': '#005049',

				background: '#F8F9FA',
				surface: '#F8F9FA',
				'surface-bright': '#F8F9FA',
				'surface-dim': '#D9DADB',
				'surface-container-lowest': '#FFFFFF',
				'surface-container-low': '#F3F4F5',
				'surface-container': '#EDEEEF',
				'surface-container-high': '#E7E8E9',
				'surface-container-highest': '#E1E3E4',
				'surface-tint': '#895100',
				'surface-variant': '#E1E3E4',

				'on-background': '#191C1D',
				'on-surface': '#191C1D',
				'on-surface-variant': '#544434',
				'inverse-surface': '#2E3132',
				'inverse-on-surface': '#F0F1F2',
				'inverse-primary': '#FFB86B',

				outline: '#877462',
				'outline-variant': '#DAC2AE',

				error: '#BA1A1A',
				'error-container': '#FFDAD6',
				'on-error': '#FFFFFF',
				'on-error-container': '#93000A'
			},
			fontFamily: {
				headline: ['"Plus Jakarta Sans"', 'sans-serif'],
				body: ['"Plus Jakarta Sans"', 'sans-serif'],
				label: ['Manrope', 'sans-serif']
			},
			borderRadius: {
				DEFAULT: '1rem',
				lg: '2rem',
				xl: '3rem',
				full: '9999px'
			}
		}
	},
	plugins: []
};
