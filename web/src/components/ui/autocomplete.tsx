import { useState, useRef, useEffect } from 'react';

interface AutocompleteProps {
  value: string;
  onChange: (value: string) => void;
  options: string[];
  placeholder?: string;
  className?: string;
  onSubmit?: () => void;
}

export default function Autocomplete({
  value,
  onChange,
  options,
  placeholder,
  className = '',
  onSubmit,
}: AutocompleteProps) {
  const [showSuggestions, setShowSuggestions] = useState(false);
  const [filteredOptions, setFilteredOptions] = useState<string[]>([]);
  const [selectedIndex, setSelectedIndex] = useState(0);
  const inputRef = useRef<HTMLInputElement>(null);
  const suggestionsRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (value) {
      const filtered = options.filter((option) =>
        option.toLowerCase().includes(value.toLowerCase())
      );
      setFilteredOptions(filtered);
      setShowSuggestions(filtered.length > 0);
      setSelectedIndex(0);
    } else {
      setFilteredOptions([]);
      setShowSuggestions(false);
    }
  }, [value, options]);

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (!showSuggestions) {
      if (e.key === 'Enter' && onSubmit) {
        e.preventDefault();
        onSubmit();
      }
      return;
    }

    switch (e.key) {
      case 'ArrowDown':
        e.preventDefault();
        setSelectedIndex((prev) => (prev + 1) % filteredOptions.length);
        break;
      case 'ArrowUp':
        e.preventDefault();
        setSelectedIndex((prev) => (prev - 1 + filteredOptions.length) % filteredOptions.length);
        break;
      case 'Enter':
        e.preventDefault();
        if (filteredOptions[selectedIndex]) {
          onChange(filteredOptions[selectedIndex]);
          setShowSuggestions(false);
        } else if (onSubmit) {
          onSubmit();
        }
        break;
      case 'Escape':
        setShowSuggestions(false);
        break;
    }
  };

  const handleSelect = (option: string) => {
    onChange(option);
    setShowSuggestions(false);
    inputRef.current?.focus();
  };

  useEffect(() => {
    const handleClickOutside = (e: MouseEvent) => {
      if (
        suggestionsRef.current &&
        !suggestionsRef.current.contains(e.target as Node) &&
        inputRef.current &&
        !inputRef.current.contains(e.target as Node)
      ) {
        setShowSuggestions(false);
      }
    };

    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  return (
    <div className="relative">
      <input
        ref={inputRef}
        type="text"
        value={value}
        onChange={(e) => onChange(e.target.value)}
        onKeyDown={handleKeyDown}
        onFocus={() => value && setShowSuggestions(filteredOptions.length > 0)}
        placeholder={placeholder}
        className={className}
      />
      {showSuggestions && filteredOptions.length > 0 && (
        <div
          ref={suggestionsRef}
          className="absolute z-10 w-full mt-1 bg-white border border-gray-300 rounded-md shadow-lg max-h-60 overflow-auto"
        >
          {filteredOptions.map((option, index) => (
            <button
              key={option}
              type="button"
              onClick={() => handleSelect(option)}
              className={`w-full text-left px-3 py-2 text-sm text-gray-900 hover:bg-gray-100 ${
                index === selectedIndex ? 'bg-gray-100' : ''
              }`}
            >
              {option}
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
