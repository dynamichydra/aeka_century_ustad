// src/components/protected-element.tsx
import { Suspense } from "react";
import ProtectedRoute from "@/components/protected-route";
import Loader from "@/components/fullpage-loader";
import { getAllowedRolesForPath } from "@/lib/route-helpers";

interface ProtectedElementProps {
  path: string;
  element: React.ReactNode;
}

export const ProtectedElement = ({ path, element }: ProtectedElementProps) => {
  const allowedRoles = getAllowedRolesForPath(path);
  return (
    <Suspense fallback={<Loader />}>
      <ProtectedRoute allowedRoles={allowedRoles}>{element}</ProtectedRoute>
    </Suspense>
  );
};
