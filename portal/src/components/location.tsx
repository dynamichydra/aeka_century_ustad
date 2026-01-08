import { useEffect, useState } from "react";
import { type UseFormSetValue, type UseFormWatch } from "react-hook-form";
import { getData } from "@/lib/commonApi";
import type { Zip } from "@/features/location/schema";
import {
  FormControl,
  FormField,
  FormItem,
  FormLabel,
  FormMessage,
} from "./ui/form";
import { Input } from "./ui/input";
import { fetchData, type AutocompleteOption } from "@/lib/hooks";
import { Autocomplete } from "./AutoComplete";

interface LocationFieldProps {
  setValue: UseFormSetValue<any>;
  watch: UseFormWatch<any>;
  control: any;
  state: string;
  city: string;
  zip: string;
  defaultZipLable?: string;
}

export function LocationField({
  setValue,
  watch,
  control,
  state,
  city,
  zip,
  defaultZipLable,
}: LocationFieldProps) {
  const zipValue = watch(zip);

  const [selectedZip, setSelectedZip] = useState<Zip | null>(null);

  // Fetch zip options for autocomplete
  const fetchZips = (query: string | number): Promise<AutocompleteOption[]> =>
    fetchData(
      "zip",
      {
        where: query
          ? [
              {
                key: "zip##code::text",
                operator: "like",
                value: query,
              },
            ]
          : [],
        select: "zip.*, s.name as sname, c.name as cname",
        reference: [
          { type: "JOIN", obj: "state s", a: "s.id", b: "zip.state" },
          { type: "JOIN", obj: "city c", a: "c.id", b: "zip.city" },
        ],
      },
      (zip) => ({
        value: zip.id?.toString()!,
        label: zip.code,
        ...zip,
      })
    );

  // Load initial zip if zipValue exists
  useEffect(() => {
    if (!zipValue) {
      setSelectedZip(null);
      setValue(city, "");
      setValue(state, "");
      return;
    }

    // Try fetch by ID first
    getData<Zip[]>("zip", {
      select: "zip.*, s.name as sname, c.name as cname",
      reference: [
        { type: "JOIN", obj: "state s", a: "s.id", b: "zip.state" },
        { type: "JOIN", obj: "city c", a: "c.id", b: "zip.city" },
      ],
      where: [{ key: "zip##id", operator: "is", value: Number(zipValue) || 0 }],
    }).then((res) => {
      let zipObj = res?.message?.[0];
      if (!zipObj) {
        // fallback: search by code
        getData<Zip[]>("zip", {
          select: "zip.*, s.name as sname, c.name as cname",
          reference: [
            { type: "JOIN", obj: "state s", a: "s.id", b: "zip.state" },
            { type: "JOIN", obj: "city c", a: "c.id", b: "zip.city" },
          ],
          where: [{ key: "zip##code::text", operator: "is", value: zipValue }],
        }).then((res2) => {
          zipObj = res2?.message?.[0];
          if (zipObj) {
            setSelectedZip(zipObj);
            setValue(city, zipObj.city.toString() ?? "");
            setValue(state, zipObj.state.toString() ?? "");
          }
        });
      } else {
        setSelectedZip(zipObj);
        setValue(city, zipObj.city.toString() ?? "");
        setValue(state, zipObj.state.toString() ?? "");
      }
    });
  }, [zipValue, watch, setValue, city, state]);

  return (
    <>
      {/* Pin code */}
      <FormField
        control={control}
        name={zip}
        render={({ field }) => (
          <FormItem>
            <FormLabel>Pin Code</FormLabel>
            <FormControl>
              <Autocomplete
                defaultLabel={defaultZipLable ?? ''}
                value={field.value}
                placeholder="Search pin code..."
                fetchOptions={fetchZips}
                error=""
                renderOption={(option) => (
                  <div className="flex justify-between items-center w-full flex-wrap border-b-[1px] py-1">
                    <span className="text-thin">{option.label}</span>
                    <span className="text-thin">
                      ({option.cname}, {option.sname})
                    </span>
                  </div>
                )}
                onChange={(val, option) => {
                  field.onChange(val); // Save zip ID or code
                  if (option) {
                    setSelectedZip(option as Zip);
                    setValue(city, option.city.toString() ?? "");
                    setValue(state, option.state.toString() ?? "");
                  } else {
                    setSelectedZip(null);
                    setValue(city, "");
                    setValue(state, "");
                  }
                }}
              />
            </FormControl>
            <FormMessage />
          </FormItem>
        )}
      />

      {/* City */}
      <FormField
        control={control}
        name={city}
        render={() => (
          <FormItem>
            <FormLabel>City</FormLabel>
            <FormControl>
              <Input
                value={selectedZip?.cname ?? ""}
                readOnly
                className="bg-muted/50"
                placeholder="City will appear here"
              />
            </FormControl>
            <FormMessage />
          </FormItem>
        )}
      />

      {/* State */}
      <FormField
        control={control}
        name={city}
        render={() => (
          <FormItem>
            <FormLabel>State</FormLabel>
            <FormControl>
              <Input
                value={selectedZip?.sname ?? ""}
                readOnly
                className="bg-muted/50"
                placeholder="State will appear here"
              />
            </FormControl>
            <FormMessage />
          </FormItem>
        )}
      />
    </>
  );
}
