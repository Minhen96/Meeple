/**
 * Locale-aware number formatting for the active locale (see ./index.ts).
 * Like m(), these read the current locale at call time and are re-run when the root layout
 * re-renders on a locale change.
 */
import { getLocale } from './index';

/** `1234` → "1,234" (en) / "1,234" (zh-CN). */
export function formatNumber(value: number, options?: Intl.NumberFormatOptions): string {
	return new Intl.NumberFormat(getLocale(), options).format(value);
}

/** A 0–100 progress value → "45%". */
export function formatPercent(value: number): string {
	return formatNumber(value / 100, {
		style: 'percent',
		maximumFractionDigits: 0
	});
}
