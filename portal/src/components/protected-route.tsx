import { useUser } from "@/hooks/use-user";
import { useEffect } from "react";
import { useNavigate } from "react-router";
import FullPageLoader from "./fullpage-loader";

type Protected = {
  children: React.ReactNode;
  allowedRoles?: string[]; // ✅ added optional role-based access
};

function ProtectedRoute({ children, allowedRoles }: Protected) {
  const navigate = useNavigate();
  const { user, isLoading } = useUser();

  useEffect(() => {
    if (isLoading) return;

    // 🔒 If not logged in
    if (!user || !user.access_token) {
      navigate("/login");
      return;
    }

    // 🚫 If allowedRoles exist but user's role isn't allowed
    if (allowedRoles && !allowedRoles.includes(user.type)) {
      navigate("/"); // redirect to home or an "Unauthorized" page
    }
  }, [user, isLoading, allowedRoles, navigate]);

  // ⏳ While loading
  if (isLoading) {
    return <FullPageLoader />;
  }

  return <>{children}</>;
}

export default ProtectedRoute;
