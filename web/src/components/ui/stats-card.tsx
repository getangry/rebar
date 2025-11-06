import type { ReactNode } from 'react';

export interface StatsCardProps {
  name: string;
  value: string | number;
  icon?: ReactNode;
  change?: {
    value: string;
    trend: 'up' | 'down' | 'neutral';
  };
  className?: string;
}

export default function StatsCard({ name, value, icon, change, className = '' }: StatsCardProps) {
  return (
    <div className={`overflow-hidden rounded-lg bg-white border border-gray-200 px-4 py-5 sm:p-6 ${className}`}>
      <div className="flex items-center">
        {icon && (
          <div className="flex-shrink-0">
            <div className="rounded-lg bg-gray-100 p-3 text-gray-700">
              {icon}
            </div>
          </div>
        )}
        <div className={icon ? 'ml-5 w-0 flex-1' : 'w-full'}>
          <dl>
            <dt className="truncate text-sm font-medium text-gray-600">{name}</dt>
            <dd className="mt-1 flex items-baseline">
              <div className="text-2xl font-semibold text-gray-900">{value}</div>
              {change && (
                <div
                  className={`ml-2 flex items-baseline text-sm font-semibold ${
                    change.trend === 'up'
                      ? 'text-green-600'
                      : change.trend === 'down'
                      ? 'text-red-600'
                      : 'text-gray-500'
                  }`}
                >
                  {change.trend === 'up' && (
                    <svg className="h-5 w-5 flex-shrink-0 self-center text-green-500" fill="currentColor" viewBox="0 0 20 20">
                      <path fillRule="evenodd" d="M5.293 9.707a1 1 0 010-1.414l4-4a1 1 0 011.414 0l4 4a1 1 0 01-1.414 1.414L11 7.414V15a1 1 0 11-2 0V7.414L6.707 9.707a1 1 0 01-1.414 0z" clipRule="evenodd" />
                    </svg>
                  )}
                  {change.trend === 'down' && (
                    <svg className="h-5 w-5 flex-shrink-0 self-center text-red-500" fill="currentColor" viewBox="0 0 20 20">
                      <path fillRule="evenodd" d="M14.707 10.293a1 1 0 010 1.414l-4 4a1 1 0 01-1.414 0l-4-4a1 1 0 111.414-1.414L9 12.586V5a1 1 0 012 0v7.586l2.293-2.293a1 1 0 011.414 0z" clipRule="evenodd" />
                    </svg>
                  )}
                  <span className="sr-only">{change.trend === 'up' ? 'Increased' : 'Decreased'} by</span>
                  {change.value}
                </div>
              )}
            </dd>
          </dl>
        </div>
      </div>
    </div>
  );
}
