import { useState } from "react";
import { Input } from "@/components/ui/input";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Button } from "@/components/ui/button";
import { Loader2Icon, Plus, RefreshCw, Search, Filter } from "lucide-react";
import { ButtonGroup } from "./ui/button-group";
import { Tooltip, TooltipContent, TooltipTrigger } from "./ui/tooltip";
import { SearchList } from "./Search";

export type SearchFieldType = "text" | "select" | "date" | "list";

export interface SearchField {
  key: string;
  label: string;
  type: SearchFieldType;
  options?: { label: string; value: string }[];
  emptyMessage?: string;
}

export interface SearchFormProps {
  fields: SearchField[];
  values: Record<string, any>;
  onChange: (key: string, value: any) => void;
  onSearch: () => void;
  onCreate: () => void;
  onReset?: () => void;
  isFetching?: boolean;
  defaultValues?: Record<string, any>;
  emptyMessage?: string;
}

export default function SearchForm({
  fields,
  values,
  onChange,
  onSearch,
  onReset,
  isFetching = false,
  defaultValues = {},
  onCreate,
  emptyMessage,
}: SearchFormProps) {
  const [showFilters, setShowFilters] = useState<boolean>(false);

  const handleReset = () => {
    if (onReset) return onReset();

    const resetValues: Record<string, any> = {};
    fields.forEach((field) => {
      resetValues[field.key] = defaultValues[field.key] ?? "";
    });

    Object.entries(resetValues).forEach(([key, val]) => onChange(key, val));
  };

  const renderFields = () => (
    <div className="flex flex-col md:flex-row gap-3">
      {fields.map((field) => {
        switch (field.type) {
          case "text":
            return (
              <Input
                key={field.key}
                value={values[field.key] ?? ""}
                onChange={(e) => onChange(field.key, e.target.value)}
                placeholder={field.label}
              />
            );

          case "select":
            return (
              <Select
                key={field.key}
                value={values[field.key] ?? ""}
                onValueChange={(v) => onChange(field.key, v)}
              >
                <SelectTrigger className="w-full">
                  <SelectValue placeholder={field.label} />
                </SelectTrigger>
                <SelectContent>
                  {field.options?.map((opt) => (
                    <SelectItem key={opt.value} value={opt.value}>
                      {opt.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            );

          case "date":
            return (
              <Input
                key={field.key}
                type="date"
                value={values[field.key] ?? ""}
                onChange={(e) => onChange(field.key, e.target.value)}
              />
            );

          case "list":
            return (
              <SearchList
                key={field.key}
                setValue={(v) => onChange(field.key, v)}
                value={values[field.key] ?? ""}
                emptyMessage={emptyMessage ?? "Not found"}
                placeholder={field.label}
                lists={field.options}
              />
            );

          default:
            return null;
        }
      })}
    </div>
  );

  return (
    <div className="w-full space-y-3">
      <div className="flex items-center justify-between lg:hidden">
        <Button
          variant="outline"
          onClick={() => setShowFilters((prev) => !prev)}
        >
          <Filter className="mr-2 h-4 w-4" />
          {showFilters ? "Hide Filters" : "Show Filters"}
        </Button>

        <Button onClick={onCreate}>
          <Plus />
        </Button>
      </div>

      {showFilters && (
        <div className="lg:hidden border rounded-md p-4 space-y-4">
          {renderFields()}

          <div className="flex justify-end gap-3">
            <Button variant="destructive" onClick={handleReset}>
              <RefreshCw />
              Reset
            </Button>

            <Button
              onClick={() => {
                onSearch();
              }}
            >
              <Search />
              Search
            </Button>
          </div>
        </div>
      )}

      <div className="hidden lg:flex gap-3 items-center flex-wrap justify-end">
        {renderFields()}

        <ButtonGroup>
          <Tooltip>
            <TooltipTrigger asChild>
              <Button variant="outline" onClick={onSearch}>
                {isFetching ? (
                  <Loader2Icon className="animate-spin" />
                ) : (
                  <Search />
                )}
              </Button>
            </TooltipTrigger>
            <TooltipContent>
              <p>Search</p>
            </TooltipContent>
          </Tooltip>

          <Tooltip>
            <TooltipTrigger asChild>
              <Button variant="destructive" onClick={handleReset}>
                <RefreshCw />
              </Button>
            </TooltipTrigger>
            <TooltipContent>
              <p>Reset</p>
            </TooltipContent>
          </Tooltip>

          <Tooltip>
            <TooltipTrigger asChild>
              <Button onClick={onCreate}>
                <Plus />
              </Button>
            </TooltipTrigger>
            <TooltipContent>
              <p>Create</p>
            </TooltipContent>
          </Tooltip>
        </ButtonGroup>
      </div>
    </div>
  );
}
