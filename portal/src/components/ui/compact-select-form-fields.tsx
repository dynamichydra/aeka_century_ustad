import { FormControl, FormItem, FormLabel, FormMessage } from './form';
import type { ControllerRenderProps } from 'react-hook-form';
import { SelectTrigger,Select,SelectContent,SelectItem,SelectValue } from './select';

interface option{
    value:String,
    label:string
}
interface props {
  field: ControllerRenderProps<any, string>;
  label: string;
  placeholder: string;
  option: option[];
}
const CompactSelectFormFields = ({ field, placeholder, label, option }: props) => {
  return (
    <FormItem className="grid-cols-3 justify-center items-center">
      <FormLabel className="text-xs">{label}</FormLabel>
      <FormControl>
        <Select
          onValueChange={field.onChange}
          value={field.value}
        >
          <SelectTrigger className="w-full col-span-2" size='sm'>
            <SelectValue placeholder={placeholder} />
          </SelectTrigger>
          <SelectContent>
            {option.map((op)=>(
            <SelectItem value={op.value as string} key={op.value as string}>{op.label}</SelectItem>
            ))}
          </SelectContent>
        </Select>
      </FormControl>
      <FormMessage className="text-xs col-span-3" />
    </FormItem>
  );
};

export default CompactSelectFormFields;