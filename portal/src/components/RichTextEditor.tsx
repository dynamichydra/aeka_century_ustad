import { CKEditor } from "@ckeditor/ckeditor5-react";
import ClassicEditor from "@ckeditor/ckeditor5-build-classic";
import { useEffect } from "react";

interface RichTextEditorProps {
  value?: string;
  onChange: (data: string) => void;
  placeholder?: string;
  disabled?: boolean;
}

export default function RichTextEditor({
  value,
  onChange,
  disabled,
}: RichTextEditorProps) {
  // Inject custom responsive styles once
  useEffect(() => {
    const styleId = "ckeditor-responsive-styles";
    if (!document.getElementById(styleId)) {
      const style = document.createElement("style");
      style.id = styleId;
      style.innerHTML = `
        .ck-editor__editable_inline {
          min-height: 160px;
          max-height: 350px;
          overflow-y: auto;
        }

        .ck.ck-toolbar {
          flex-wrap: wrap !important;
        }

        .ck.ck-toolbar .ck-toolbar__items {
          flex-wrap: wrap !important;
        }

        .ck.ck-editor {
          width: 100% !important;
          max-width: 100%;
          box-sizing: border-box;
        }

        .ck.ck-editor__main {
          width: 100%;
        }

        /* Muted look when disabled */
        .ck-editor__editable[contenteditable="false"] {
          background-color: #f9fafb !important;
          color: #6b7280 !important; /* gray-500 */
        }

        @media (max-width: 768px) {
          .ck.ck-toolbar {
            font-size: 12px;
            padding: 4px;
          }
        }
      `;
      document.head.appendChild(style);
    }
  }, []);

  return (
    <div className="border rounded-md w-full overflow-hidden">
      <CKEditor
        editor={ClassicEditor as any}
        data={value}
        onChange={(_, editor) => onChange(editor.getData())}
        disabled={disabled}
      />
    </div>
  );
}
