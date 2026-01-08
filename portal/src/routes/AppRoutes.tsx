import { Suspense, lazy } from "react";
import { createBrowserRouter, RouterProvider } from "react-router-dom";
import Loader from "@/components/fullpage-loader";

// Lazy imports
const Login = lazy(() => import("@/features/auth/pages/Login"));
const Register = lazy(() => import("@/features/auth/pages/Register"));
const Root = lazy(() => import("@/layouts/Root"));
const Home = lazy(() => import("@/features/home/pages"));

// Users
const UserList = lazy(() =>
  import("@/features/users/pages").then((m) => ({ default: m.UserList }))
);
const UserCreate = lazy(() =>
  import("@/features/users/pages").then((m) => ({ default: m.UserCreate }))
);
const UserEdit = lazy(() =>
  import("@/features/users/pages").then((m) => ({ default: m.UserEdit }))
);
const ResetPassowrd = lazy(() =>
  import("@/features/users/pages").then((m) => ({ default: m.ResetPassowrd }))
);
const Profile = lazy(() =>
  import("@/features/users/pages").then((m) => ({ default: m.Profile }))
);

// Misc
const NotFound = lazy(() =>
  import("@/features/notfound/pages").then((m) => ({ default: m.NotFound }))
);

const router = createBrowserRouter([
  {
    path: "/login",
    element: (
      <Suspense fallback={<Loader />}>
        <Login />
      </Suspense>
    ),
  },
  {
    path: "/register",
    element: (
      <Suspense fallback={<Loader />}>
        <Register />
      </Suspense>
    ),
  },
  {
    path: "/",
    element: <Root />,
    children: [
      { index: true, element: <Home /> },
      {
        path: "user",
        children: [
          {
            index: true,
            element: <UserList />,
          },
          {
            path: "create",
            element: <UserCreate />,
          },
          {
            path: "edit/:id",
            element: <UserEdit />,
          },
          { path: "reset-password", element: <ResetPassowrd /> },
          { path: "profile", element: <Profile /> },
          // {path: "/login", element: <Suspense fallback={<Loader />}><Login /></Suspense>},
        ],
      },
    ],
  },
  {
    path: "*",
    element: (
      <Suspense fallback={<Loader />}>
        <NotFound />
      </Suspense>
    ),
  },
]);

export default function AppRoutes() {
  return <RouterProvider router={router} />;
}
