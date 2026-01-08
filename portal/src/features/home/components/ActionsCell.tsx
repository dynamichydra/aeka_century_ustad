// components/ActionsCell.tsx
import { Button } from "@/components/ui/button";
import { useNavigate } from "react-router-dom";
import { useState } from "react";
import ConfirmDeleteModal from "./ConfirmDeleteModal";
import { Edit2, Trash } from "lucide-react";
import type { Payment } from "./columns";

type ActionsCellProps = {
  user: Payment;
  onDelete: (id: string) => void; // NEW
};

export default function ActionsCell({ user, onDelete }: ActionsCellProps) {
  const navigate = useNavigate();
  const [showModal, setShowModal] = useState(false);
  const handleDelete = async () => {
    try {
      console.log("DELETE API CALL");
      onDelete(user.id);
      setTimeout(() => {
        setShowModal(false);
      }, 1000);
    } catch (error) {
      console.error("Delete failed:", error);
    } finally {
      setShowModal(false);
    }
  };

  return (
    <>
      <div className="flex gap-2">
        <Button
          variant="outline"
          size="sm"
          onClick={() => navigate(`/user/edit/${user.id}`)}
        >
          <Edit2 />
        </Button>

        <Button
          variant="destructive"
          size="sm"
          onClick={() => setShowModal(true)}
        >
          <Trash />
        </Button>
      </div>

      {showModal && (
        <ConfirmDeleteModal
          confirmationText={`Are you sure you want to delete ${user.email}?`}
          onCancel={() => setShowModal(false)}
          onConfirm={handleDelete}
        />
      )}
    </>
  );
}
