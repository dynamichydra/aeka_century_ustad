import { CKEditor } from "@ckeditor/ckeditor5-react";
import ClassicEditor from "@ckeditor/ckeditor5-build-classic";

interface RichTextEditorProps {
  value?: string;
  onChange: (data: string) => void;
  placeholder?: string;
  disabled?: boolean
}

export default function RichTextEditor({
  value,
  onChange,
  disabled
}: RichTextEditorProps) {
  return (
    <div className="border rounded">
      <CKEditor
        onChange={(_, editor) => {
          const data = editor.getData();
          onChange(data);
        }}
        editor={ClassicEditor as any}
        data={value}
        disabled ={disabled}
      />
    </div>
  );
}
