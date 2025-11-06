import { forwardRef } from 'react';
import type { HTMLAttributes } from 'react';

export interface BadgeProps extends HTMLAttributes<HTMLDivElement> {
  variant?: 'default' | 'success' | 'destructive' | 'warning' | 'secondary' | 'outline';
}

const Badge = forwardRef<HTMLDivElement, BadgeProps>(
  ({ className = '', variant = 'default', ...props }, ref) => {
    const baseStyles = 'inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-semibold transition-colors focus:outline-none focus:ring-2 focus:ring-primary-500 focus:ring-offset-2';

    const variants = {
      default: 'bg-primary-500 text-white hover:bg-primary-600',
      success: 'bg-green-500 text-white hover:bg-green-600',
      destructive: 'bg-red-500 text-white hover:bg-red-600',
      warning: 'bg-yellow-500 text-white hover:bg-yellow-600',
      secondary: 'bg-gray-100 text-gray-900 hover:bg-gray-200',
      outline: 'border border-gray-300 text-gray-900',
    };

    return (
      <div
        ref={ref}
        className={`${baseStyles} ${variants[variant]} ${className}`}
        {...props}
      />
    );
  }
);

Badge.displayName = 'Badge';

export default Badge;
