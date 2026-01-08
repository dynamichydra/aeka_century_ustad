// components/IconPicker.tsx
import { useMemo, useState } from "react";
import { ALL_LUCIDE_ICONS, type IconEntry } from "@/lib/all-lucide-icons";

import { Button } from "@/components/ui/button";
import {
  Popover,
  PopoverTrigger,
  PopoverContent,
} from "@/components/ui/popover";
import {
  Command,
  CommandInput,
  CommandList,
  CommandEmpty,
  CommandGroup,
  CommandItem,
} from "@/components/ui/command";
import { ChevronsUpDown, CircleDot } from "lucide-react";
import { cn } from "@/lib/utils";

type IconPickerProps = {
  /** kebab-case icon name, e.g. "alarm-clock" */
  value?: string | null;
  onChange: (value: string) => void;
  placeholder?: string;
  className?: string;
};

export function IconPicker({
  value,
  onChange,
  placeholder = "Choose an icon",
  className,
}: IconPickerProps) {
  const [open, setOpen] = useState(false);

  const selected: IconEntry | undefined = useMemo(
    () => ALL_LUCIDE_ICONS.find((icon) => icon.name === value),
    [value]
  );

  return (
    <Popover open={open} onOpenChange={setOpen}>
      <PopoverTrigger asChild>
        <Button
          type="button"
          variant="outline"
          role="combobox"
          className={cn(
            "w-full justify-between font-normal",
            !selected && "text-muted-foreground",
            className
          )}
        >
          <span className="flex items-center gap-2">
            {selected ? (
              <>
                <selected.component className="h-4 w-4" />
                <span className="truncate">{selected.name}</span>
              </>
            ) : (
              <>
                <CircleDot className="h-4 w-4 opacity-50" />
                <span>{placeholder}</span>
              </>
            )}
          </span>
          <ChevronsUpDown className="ml-2 h-4 w-4 shrink-0 opacity-50" />
        </Button>
      </PopoverTrigger>

      <PopoverContent className="w-80 p-0" align="start">
        <Command>
          <CommandInput placeholder="Search icons…" />
          <CommandList className="max-h-72">
            <CommandEmpty>No icon found.</CommandEmpty>
            <CommandGroup heading="Lucide icons">
              {ALL_LUCIDE_ICONS.map((icon) => (
                <CommandItem
                  key={icon.name}
                  value={icon.name} // used for search
                  onSelect={() => {
                    onChange(icon.name);
                    setOpen(false);
                  }}
                  className="flex items-center gap-2"
                >
                  <icon.component className="h-4 w-4" />
                  <span className="truncate">{icon.name}</span>
                </CommandItem>
              ))}
            </CommandGroup>
          </CommandList>
        </Command>
      </PopoverContent>
    </Popover>
  );
}
