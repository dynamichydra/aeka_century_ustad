import { ChartBarMultiple } from "./stock-chart";
import OrderChart from "./order-chart";
import RequestTable from "./request-table";
import { useUser } from "@/hooks/use-user";

export default function Dashboard() {
  const { user } = useUser();
  return (
    <div className="grid grid-cols-12 gap-3">
      {user?.id !== undefined && user.type != "Sales" && (
        <OrderChart branch={Number(user.branch[0])} type={user.type} />
      )}
      {user?.id !== undefined && (
        <RequestTable
          uId={Number(user.id)}
          branch={Number(user.branch[0])}
          type={user.type}
        />
      )}
      {user?.id !== undefined && user.type != "Sales" && (
        <ChartBarMultiple user={user} link="/branch/stock" />
      )}
    </div>
  );
}
