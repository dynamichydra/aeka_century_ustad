import { useEffect, useState } from "react";
import { type UseFormSetValue, type UseFormWatch } from "react-hook-form";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { getData } from "@/lib/commonApi";
import {
  FormControl,
  FormField,
  FormItem,
  FormLabel,
  FormMessage,
} from "./ui/form";
import type { RegionFormData } from "@/features/region/regionSchema";

interface RegionFieldProps {
  setValue: UseFormSetValue<any>;
  watch: UseFormWatch<any>;
  control: any;
  region: string;
}

export function RegionField({
  setValue,
  watch,
  control,
  region,
}: RegionFieldProps) {
  const [regions, setRegions] = useState<RegionFormData[]>([]);

  // Fetch all regions on mount
  useEffect(() => {
    getData<RegionFormData[]>("region").then((res) => {
      const data = res?.message ?? [];
      setRegions(data);

      // Set default value if not already set
      if (data.length && !watch(region)) {
        setValue(region, data[0].id?.toString(), {
          shouldValidate: true,
          shouldDirty: true,
        });
      }
    });
  }, [setValue, region, watch]);

  // Watch the selected region
  const selectedRegion = watch(region);

  return (
    <FormField
      control={control}
      name={region}
      render={() => (
        <FormItem>
          <FormLabel>Region</FormLabel>
          <FormControl>
            {/* <Select
              value={selectedRegion}
              onValueChange={(val) => {
                setValue(region, val, { shouldValidate: true });
              }}
            > */}

            <Select
              value={selectedRegion}
              onValueChange={(val) => {
                setValue(region, val, { shouldValidate: true });
              }}
            >
              <SelectTrigger className="w-full">
                <SelectValue placeholder="Select region" />
              </SelectTrigger>
              <SelectContent>
                {regions.map((r) => (
                  <SelectItem key={r.id} value={r.id?.toString()!}>
                    {r.name}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </FormControl>
          <FormMessage />
        </FormItem>
      )}
    />
  );
}
