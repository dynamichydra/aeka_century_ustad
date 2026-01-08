import {
  FormField,
  FormItem,
  FormLabel,
  FormControl,
  FormMessage,
} from "@/components/ui/form";
import {
  Select,
  SelectTrigger,
  SelectValue,
  SelectContent,
  SelectItem,
} from "@/components/ui/select";
import { Textarea } from "@/components/ui/textarea";
import { useGetData } from "@/lib/hooks";
import type { Notes } from "@/features/settings/type";
import { useEffect, useMemo, useState } from "react";

type Option = { label: string; value: string };

interface RemarksFieldProps {
  form: any;
  name: string; // e.g. "remark"
  label?: string;
  type?: string;
  placeholder?: string;
  showCustom?: boolean;
}

export function RemarksField({
  form,
  name,
  label = "Remark",
  type = "approve",
  placeholder = "Select remark",
  showCustom = true,
}: RemarksFieldProps) {
  const { data: notes } = useGetData<Notes[]>("notes", {
    where: [
      { key: "type", value: type, operator: "is" },
      { key: "status", value: "active", operator: "is" },
    ],
  });

  const options = useMemo<Option[]>(
    () =>
      notes?.message?.map((n) => ({
        value: n.text ?? "",
        label: n.text ?? "",
      })) ?? [],
    [notes]
  );

  const remarkValue: string = form.watch(name) ?? "";

  // ✅ Local state for textarea visibility and custom text
  const [showTextarea, setShowTextarea] = useState(false);
  const [customText, setCustomText] = useState("");

  // determine if remark is one of predefined options
  const isPredefined = options.some((o) => o.value === remarkValue);

  // ✅ only run on mount or when remark changes, not every render
  useEffect(() => {
    // avoid calling setState if nothing changes
    if (showCustom && remarkValue && !isPredefined) {
      setShowTextarea(true);
      setCustomText(remarkValue);
    } else if (isPredefined) {
      setShowTextarea(false);
      setCustomText("");
    }
  }, [remarkValue, isPredefined, showCustom]);

  // ✅ handle select change safely
  const handleSelectChange = (val: string) => {
    if (val === "Other") {
      setShowTextarea(true);
      setCustomText("");
      // clear the field only if not already empty
      if (form.getValues(name) !== "") {
        form.setValue(name, "", { shouldValidate: false });
      }
    } else {
      setShowTextarea(false);
      setCustomText("");
      form.setValue(name, val, { shouldValidate: true });
    }
  };

  const selectValue = showTextarea ? "Other" : isPredefined ? remarkValue : "";

  return (
    <>
      <FormField
        control={form.control}
        name={name}
        render={() => (
          <FormItem>
            <FormLabel>{label}</FormLabel>
            <FormControl>
              <Select onValueChange={handleSelectChange} value={selectValue}>
                <SelectTrigger className="w-full">
                  <SelectValue placeholder={placeholder} />
                </SelectTrigger>
                <SelectContent>
                  {options.map((opt) => (
                    <SelectItem key={opt.value} value={opt.value}>
                      {opt.label}
                    </SelectItem>
                  ))}
                  {showCustom && <SelectItem value="Other">Other</SelectItem>}
                </SelectContent>
              </Select>
            </FormControl>
            <FormMessage />
          </FormItem>
        )}
      />

      {showTextarea && (
        <FormField
          control={form.control}
          name={name}
          render={() => (
            <FormItem className="mt-2">
              <FormLabel>Note</FormLabel>
              <FormControl>
                <Textarea
                  placeholder="Enter note"
                  value={customText}
                  onChange={(e) => {
                    const val = e.target.value;
                    setCustomText(val);
                    form.setValue(name, val, { shouldValidate: true });
                  }}
                />
              </FormControl>
              <FormMessage />
            </FormItem>
          )}
        />
      )}
    </>
  );
}

