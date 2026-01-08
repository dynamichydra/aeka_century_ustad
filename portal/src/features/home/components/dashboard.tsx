import { useUser } from "@/hooks/use-user";
import { useNavigate } from "react-router";

export default function Dashboard() {
  const {user} = useUser();
  const navigate = useNavigate()
 if (!user) {
  navigate('/login')
 }


  return (
    <section className="grid grid-cols-12 gap-3">
      WellCome User
    </section>
  );
}
