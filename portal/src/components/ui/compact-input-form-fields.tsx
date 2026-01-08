import { FormControl, FormItem, FormLabel, FormMessage } from "./form";
import { CompactInput } from "./compact-input";
import type { ControllerRenderProps } from "react-hook-form";
import type React from "react";

export type InputType = "text" | "number" | "email" | "password" | "tel" | "url" | "date" | "file";
interface Props {
  field: ControllerRenderProps<any, string>;
  label: string;
  placeholder?: string;
  children?: React.ReactNode;
  inputType?: InputType;
  lableActionButton?: React.ReactNode;
}

const CompactInputFormFields = ({
  field,
  label,
  placeholder,
  children,
  inputType = "text",
  lableActionButton,
}: Props) => {
  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const value = e.target.value;
    field.onChange(
      inputType === "number" ? (value === "" ? "" : Number(value)) : value
    );
  };

  return (
    <FormItem className="grid grid-cols-3 items-center gap-2">
      <FormLabel className="text-xs flex justify-start items-center gap-2">
        {label} {lableActionButton}
      </FormLabel>
      <FormControl className="col-span-2">
        {children ? (
          children
        ) : (
          <CompactInput
            className="border rounded text-sm w-full"
            placeholder={placeholder}
            type={inputType}
            {...field}
            value={field.value?.toString() ?? ""}
            onChange={handleChange}
          />
        )}
      </FormControl>
      <FormMessage className="text-xs col-span-3" />
    </FormItem>
  );
};

export default CompactInputFormFields;
