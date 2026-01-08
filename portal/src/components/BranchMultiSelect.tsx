import * as React from "react";
import {
  Popover,
  PopoverTrigger,
  PopoverContent,
} from "@/components/ui/popover";
import { Command, CommandGroup, CommandItem, CommandInput, CommandList, CommandEmpty } from "@/components/ui/command";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Check, ChevronsUpDown } from "lucide-react";
import { cn } from "@/lib/utils";

interface Option {
  label: string;
  value: string;
}

interface BranchMultiSelectProps {
  options: Option[];
  value: string[];
  onChange: (value: string[]) => void;
  placeholder?: string;
}

export function BranchMultiSelect({
  options,
  value,
  onChange,
  placeholder = "Select branches",
}: BranchMultiSelectProps) {
  const [open, setOpen] = React.useState(false);

  const toggleOption = (val: string) => {
    if (value.includes(val)) {
      onChange(value.filter((v) => v !== val));
    } else {
      onChange([...value, val]);
    }
  };

  return (
    <Popover open={open} onOpenChange={setOpen}>
      <PopoverTrigger asChild>
        <Button
          variant="outline"
          role="combobox"
          className={cn(
            "w-full justify-between min-h-[44px] h-auto",
            value.length > 0 ? "flex-wrap" : ""
          )}
        >
          <div className="flex flex-wrap gap-1 items-center overflow-hidden">
            {value.length === 0 && (
              <span className="text-muted-foreground">{placeholder}</span>
            )}
            {value.map((val) => {
              const label = options.find((o) => o.value === val)?.label ?? val;
              return (
                <Badge
                  key={val}
                  variant="secondary"
                  className="flex items-center gap-1 truncate max-w-[120px]"
                >
                  <span className="truncate">{label}</span>
                </Badge>
              );
            })}
          </div>
          <ChevronsUpDown className="ml-auto h-4 w-4 shrink-0 opacity-50" />
        </Button>
      </PopoverTrigger>

      <PopoverContent className="w-[var(--radix-popover-trigger-width)] p-0">
        <Command>
          <CommandInput placeholder="Search branch..." />
          <CommandList>
            <CommandEmpty>No branch found.</CommandEmpty>
            <CommandGroup>
              {options.map((option) => (
                <CommandItem
                  key={option.value}
                  onSelect={() => toggleOption(option.value)}
                >
                  <Check
                    className={cn(
                      "mr-2 h-4 w-4",
                      value.includes(option.value) ? "opacity-100" : "opacity-0"
                    )}
                  />
                  {option.label}
                </CommandItem>
              ))}
            </CommandGroup>
          </CommandList>
        </Command>
      </PopoverContent>
    </Popover>
  );
}
