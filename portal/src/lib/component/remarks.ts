import { FormField, FormItem, FormLabel, FormControl, FormMessage } from "@/components/ui/form"
import { Select, SelectTrigger, SelectValue, SelectContent, SelectItem } from "@/components/ui/select"
import { useGetData } from "@/lib/hooks"
import type { ItemStatus, ActionType } from "@/lib/types";
export type Notes = {
  id?: number;
  text?: string;
  type?: ActionType;
  created_by: string;
  created_at: string;
  status: ItemStatus;
};
type Option = {
  label: string
  value: string
}

interface SelectFieldProps {
  form: any
  name: string
  label: string
  type?: string
  placeholder?: string
  showCustom?: boolean
}

export function RemarksField({
  form,
  name,
  label,
  type = "approve",
  placeholder = "Select remarks",
  showCustom = false,
}: SelectFieldProps) {
  const { data: notes } = useGetData<Notes[]>("notes", {
    where: [
        { key: "type", value: type, operator: "is" },
        { key: "status", value: 'active', operator: "is" }
    ]
  })
  console.log(notes)
  const options: Option[] =
    notes?.message.map((note) => ({
      value: note.text ?? "",
      label: note.text ?? "",
    })) ?? []

  return FormField({
    control: form.control,
    name: name,
    render: ({ field }: any) =>
      FormItem({
        children: [
          FormLabel({ children: label }),
          FormControl({
            children:
            //   value === "Custom" && showCustom
            //     ? Textarea({
            //         placeholder: "Enter custom remarks",
            //         ...field,
            //         value: field.value === "Custom" ? "" : field.value,
            //         onChange: (e: any) => field.onChange(e.target.value),
            //       })
            //     : 
                Select({
                    onValueChange: field.onChange,
                    value: field.value,
                    children: [
                      SelectTrigger({
                        className: "w-full",
                        children: SelectValue({ placeholder }),
                      }),
                      SelectContent({
                        children: [
                          ...options.map((opt) =>
                            SelectItem({
                              key: opt.value,
                              value: opt.value,
                              children: opt.label,
                            })
                          ),
                          showCustom
                            ? SelectItem({
                                value: "Custom",
                                children: "Custom",
                              })
                            : null,
                        ],
                      }),
                    ],
                  }),
          }),
          FormMessage({}),
        ],
      }),
  })
}