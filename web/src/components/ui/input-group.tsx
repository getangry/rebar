import type { ReactNode } from 'react';
import Label from './label';
import Input from './input';
import Select from './select';
import type { InputProps } from './input';
import type { SelectProps } from './select';

export interface InputGroupProps extends Omit<InputProps, 'id'> {
  label: string;
  id: string;
  helpText?: string;
  error?: string;
  leadingAddon?: ReactNode;
  trailingAddon?: ReactNode;
}

export function InputGroup({
  label,
  id,
  helpText,
  error,
  leadingAddon,
  trailingAddon,
  className = '',
  ...inputProps
}: InputGroupProps) {
  return (
    <div className="space-y-1">
      <Label htmlFor={id}>{label}</Label>
      <div className="relative rounded-md shadow-sm">
        {leadingAddon && (
          <div className="pointer-events-none absolute inset-y-0 left-0 flex items-center pl-3">
            <span className="text-gray-500 sm:text-sm">{leadingAddon}</span>
          </div>
        )}
        <Input
          id={id}
          className={`${leadingAddon ? 'pl-10' : ''} ${trailingAddon ? 'pr-10' : ''} ${
            error ? 'border-red-300 focus:ring-red-500 focus:border-red-500' : ''
          } ${className}`}
          {...inputProps}
        />
        {trailingAddon && (
          <div className="pointer-events-none absolute inset-y-0 right-0 flex items-center pr-3">
            <span className="text-gray-500 sm:text-sm">{trailingAddon}</span>
          </div>
        )}
      </div>
      {helpText && !error && <p className="text-sm text-gray-500">{helpText}</p>}
      {error && <p className="text-sm text-red-600">{error}</p>}
    </div>
  );
}

export interface SelectGroupProps extends Omit<SelectProps, 'id'> {
  label: string;
  id: string;
  helpText?: string;
  error?: string;
}

export function SelectGroup({
  label,
  id,
  helpText,
  error,
  className = '',
  children,
  ...selectProps
}: SelectGroupProps) {
  return (
    <div className="space-y-1">
      <Label htmlFor={id}>{label}</Label>
      <Select
        id={id}
        className={`${error ? 'border-red-300 focus:ring-red-500 focus:border-red-500' : ''} ${className}`}
        {...selectProps}
      >
        {children}
      </Select>
      {helpText && !error && <p className="text-sm text-gray-500">{helpText}</p>}
      {error && <p className="text-sm text-red-600">{error}</p>}
    </div>
  );
}
