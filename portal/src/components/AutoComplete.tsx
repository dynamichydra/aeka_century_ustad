import React, {
  useState,
  useEffect,
  useCallback,
  forwardRef,
  useRef,
  useImperativeHandle,
} from "react";
import { cn } from "@/lib/utils";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { ScrollArea } from "@/components/ui/scroll-area";
import { Check, ChevronsUpDown, Loader2 } from "lucide-react";

export interface AutocompleteOption {
  value: string;
  label: string;
  [key: string]: any;
}

export interface AutocompleteProps {
  value: string;
  onChange: (value: string, option?: AutocompleteOption) => void;
  fetchOptions: (query: string | number) => Promise<AutocompleteOption[]>;
  label?: string;
  placeholder?: string;
  emptyMessage?: string;
  disabled?: boolean;
  className?: string;
  inputclassName?: string;
  renderOption?: (option: AutocompleteOption) => React.ReactNode;
  getDisplayValue?: (option: AutocompleteOption | null) => string;
  debounceDelay?: number;
  defaultLabel?: string;
  error: string;
  showDescription?: boolean;
  queryLength?: number;
}

const DefaultOptionRenderer = ({ option }: { option: AutocompleteOption }) => (
  <div className="flex items-center">
    <Check
      className={cn("mr-2 h-4 w-4 opacity-0", "group-selected:opacity-100")}
    />
    <span>{option.label}</span>
  </div>
);

const defaultGetDisplayValue = (option: AutocompleteOption | null) =>
  option?.label || "";

export const Autocomplete = forwardRef<HTMLDivElement, AutocompleteProps>(
  (
    {
      value,
      onChange,
      fetchOptions,
      label,
      placeholder = "Search...",
      emptyMessage = "No results found.",
      disabled = false,
      className,
      inputclassName,
      renderOption = (option) => <DefaultOptionRenderer option={option} />,
      getDisplayValue = defaultGetDisplayValue,
      debounceDelay = 300,
      defaultLabel,
      error,
      showDescription = false,
      queryLength = 3,
    },
    ref
  ) => {
    const [open, setOpen] = useState(false);
    const [options, setOptions] = useState<AutocompleteOption[]>([]);
    const [isLoading, setIsLoading] = useState(false);
    const [searchQuery, setSearchQuery] = useState("");
    const [inputValue, setInputValue] = useState(defaultLabel ?? "");
    const [description, setDescription] = useState<any>(defaultLabel ?? "");
    const internalRef = useRef<HTMLDivElement | null>(null);

    // Expose internalRef to parent
    useImperativeHandle(ref, () => internalRef.current as HTMLDivElement);

    const selectedOption =
      options.find((option) => option.value === value) || null;

    // Update input when option changes
    useEffect(() => {
      if (selectedOption) {
        setInputValue(getDisplayValue(selectedOption));
      }
    }, [selectedOption, getDisplayValue]);

    // Debounced fetch
    const debouncedFetch = useCallback(
      async (query: string) => {
        if (query.length < queryLength) {
          setOptions([]);
          return;
        }
        setIsLoading(true);
        try {
          const data = await fetchOptions(query);
          setOptions(data);
        } catch (error) {
          console.error("Failed to fetch options:", error);
          setOptions([]);
        } finally {
          setIsLoading(false);
        }
      },
      [fetchOptions]
    );

    useEffect(() => {
      const handler = setTimeout(() => {
        if (open) debouncedFetch(searchQuery);
      }, debounceDelay);

      return () => clearTimeout(handler);
    }, [searchQuery, open, debounceDelay, debouncedFetch]);

    // const handleSelect = (option: AutocompleteOption) => {
    //   onChange(option.value);
    //   setInputValue(option.label);
    //   setDescription(renderOption(option));
    //   setOpen(false);
    //   setSearchQuery("");
    // };
    const handleSelect = (option: AutocompleteOption) => {
      onChange(option.value, option); // pass full option
      setInputValue(option.label);
      setDescription(renderOption(option));
      setOpen(false);
      setSearchQuery("");
    };

    const handleInputChange = (value: string) => {
      setInputValue(value);
      setSearchQuery(value);
      if (!options.some((option) => getDisplayValue(option) === value)) {
        onChange("");
      }
    };

    // Close when clicking outside
    useEffect(() => {
      function handleClickOutside(event: MouseEvent) {
        if (
          internalRef.current &&
          !internalRef.current.contains(event.target as Node)
        ) {
          setOpen(false);
        }
      }
      if (open) {
        document.addEventListener("mousedown", handleClickOutside);
      } else {
        document.removeEventListener("mousedown", handleClickOutside);
      }
      return () => {
        document.removeEventListener("mousedown", handleClickOutside);
      };
    }, [open]);

    return (
      <div className={cn("flex flex-col", className)} ref={internalRef}>
        {label && <label className="mb-1 text-sm font-medium">{label}</label>}
        <div className="relative">
          <div className="relative">
            <Input
              value={inputValue}
              onChange={(e) => handleInputChange(e.target.value)}
              onFocus={() => setOpen(true)}
              placeholder={placeholder}
              disabled={disabled}
              className={cn("pr-10", inputclassName)}
            />
            <Button
              type="button"
              variant="ghost"
              className="absolute right-0 top-0 h-full px-3"
              onClick={() => setOpen(!open)}
              disabled={disabled}
            >
              <ChevronsUpDown className="h-4 w-4 text-muted-foreground" />
            </Button>
          </div>

          {open && (
            <div className="absolute z-50 w-full mt-1 bg-popover border rounded-md shadow-md">
              <ScrollArea className="h-40">
                {isLoading ? (
                  <div className="flex items-center justify-center py-6">
                    <Loader2 className="h-6 w-6 animate-spin" />
                  </div>
                ) : options.length === 0 ? (
                  <div className="py-6 text-center text-sm text-muted-foreground">
                    {emptyMessage}
                  </div>
                ) : (
                  <div className="p-1">
                    {options.map((option) => (
                      <div
                        key={option.value}
                        className={cn(
                          "relative flex cursor-pointer select-none items-center rounded-sm px-2 py-1.5 text-sm outline-none",
                          "hover:bg-accent hover:text-accent-foreground",
                          "data-[selected=true]:bg-accent data-[selected=true]:text-accent-foreground",
                          "group"
                        )}
                        data-selected={value === option.value}
                        onClick={() => handleSelect(option)}
                      >
                        {renderOption(option)}
                      </div>
                    ))}
                  </div>
                )}
              </ScrollArea>
            </div>
          )}
        </div>
        {showDescription && description && <>{description}</>}
        {error && <p className="text-sm text-red-500 mt-1">{error}</p>}
      </div>
    );
  }
);

Autocomplete.displayName = "Autocomplete";
