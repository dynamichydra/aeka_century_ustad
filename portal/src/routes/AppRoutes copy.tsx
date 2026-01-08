import { Suspense, lazy } from "react";
import { createBrowserRouter, RouterProvider } from "react-router-dom";

import Loader from "@/components/fullpage-loader";
// 🔹 Lazy imports
const Login = lazy(() => import("@/features/auth/pages/Login"));
const Register = lazy(() => import("@/features/auth/pages/Register"));
const ProtectedRoute = lazy(() => import("@/components/protected-route"));
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

// Branch
const BranchList = lazy(() =>
  import("@/features/branche/pages").then((m) => ({ default: m.BranchList }))
);
const BranchCreate = lazy(() =>
  import("@/features/branche/pages/index").then((m) => ({
    default: m.BranchCreate,
  }))
);
const BranchEdit = lazy(() =>
  import("@/features/branche/pages").then((m) => ({ default: m.BranchEdit }))
);

const Request = lazy(() =>
  import("@/features/sample-request/pages").then((m) => ({
    default: m.Request,
  }))
);
const Stock = lazy(() =>
  import("@/features/branche/pages").then((m) => ({ default: m.Stock }))
);
const OrderList = lazy(() =>
  import("@/features/branche/pages").then((m) => ({ default: m.OrderList }))
);

const OrderDetails = lazy(() =>
  import("@/features/branche/pages").then((m) => ({
    default: m.OrderDetails,
  }))
);
const CreateSampleRequest = lazy(() =>
  import("@/features/sample-request/pages").then((m) => ({
    default: m.createSampleRequest,
  }))
);

const RequestList = lazy(() =>
  import("@/features/sales/pages").then((m) => ({
    default: m.requestList,
  }))
);

// Settings
const General = lazy(() =>
  import("@/features/settings/pages").then((m) => ({ default: m.General }))
);
const Product = lazy(() =>
  import("@/features/product/pages").then((m) => ({ default: m.Product }))
);
const EditProduct = lazy(() =>
  import("@/features/product/pages").then((m) => ({ default: m.EditProduct }))
);
const CreateProduct = lazy(() =>
  import("@/features/product/pages").then((m) => ({ default: m.CreateProduct }))
);

const Influencer = lazy(() =>
  import("@/features/influencer/pages").then((m) => ({
    default: m.InfluencerList,
  }))
);
const CreateInfluencer = lazy(() =>
  import("@/features/influencer/pages").then((m) => ({
    default: m.CreateInfluencer,
  }))
);
const EditInfluencer = lazy(() =>
  import("@/features/influencer/pages").then((m) => ({
    default: m.EditInfluencer,
  }))
);

const Project = lazy(() =>
  import("@/features/project/pages").then((m) => ({ default: m.Project }))
);

const EditProject = lazy(() =>
  import("@/features/project/pages").then((m) => ({ default: m.EditProject }))
);

const CreateProject = lazy(() =>
  import("@/features/project/pages").then((m) => ({ default: m.CreateProject }))
);

// Region

const Region = lazy(() =>
  import("@/features/region/pages").then((m) => ({ default: m.Region }))
);

const EditRegion = lazy(() =>
  import("@/features/region/pages").then((m) => ({ default: m.EditRegion }))
);

const CreateRegion = lazy(() =>
  import("@/features/region/pages").then((m) => ({ default: m.CreateRegion }))
);

const Notification = lazy(() =>
  import("@/features/settings/pages").then((m) => ({ default: m.Notification }))
);
const Notes = lazy(() =>
  import("@/features/settings/pages").then((m) => ({ default: m.Notes }))
);
const CreateNote = lazy(() =>
  import("@/features/settings/pages").then((m) => ({ default: m.CreateNote }))
);
const EditNote = lazy(() =>
  import("@/features/settings/pages").then((m) => ({
    default: m.EditNote,
  }))
);

// Location

const State = lazy(() =>
  import("@/features/location/pages").then((m) => ({ default: m.StateLists }))
);
const City = lazy(() =>
  import("@/features/location/pages").then((m) => ({ default: m.CityLists }))
);
const Pin = lazy(() =>
  import("@/features/location/pages").then((m) => ({ default: m.PinLists }))
);
// Misc
const NotFound = lazy(() =>
  import("@/features/notfound/pages").then((m) => ({ default: m.NotFound }))
);

// Damage book

const DamageList = lazy(() =>
  import("@/features/damage/pages").then((m) => ({ default: m.DamageList }))
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
    element: (
      <Suspense fallback={<Loader />}>
        <ProtectedRoute>
          <Root />
        </ProtectedRoute>
      </Suspense>
    ),
    children: [
      {
        index: true,
        element: (
          <Suspense fallback={<Loader />}>
            <Home />
          </Suspense>
        ),
      },
      {
        path: "user",
        children: [
          {
            index: true,
            element: (
              <Suspense fallback={<Loader />}>
                <UserList />
              </Suspense>
            ),
          },
          {
            path: "create",
            element: (
              <Suspense fallback={<Loader />}>
                <UserCreate />
              </Suspense>
            ),
          },
          {
            path: "edit/:id",
            element: (
              <Suspense fallback={<Loader />}>
                <UserEdit />
              </Suspense>
            ),
          },
          {
            path: "reset-password",
            element: (
              <Suspense fallback={<Loader />}>
                <ResetPassowrd />
              </Suspense>
            ),
          },
          {
            path: "profile",
            element: (
              <Suspense fallback={<Loader />}>
                <Profile />
              </Suspense>
            ),
          },
        ],
      },
      {
        path: "settings",
        children: [
          {
            path: "general",
            element: (
              <Suspense fallback={<Loader />}>
                <General />
              </Suspense>
            ),
          },
          {
            path: "notification",
            element: (
              <Suspense fallback={<Loader />}>
                <Notification />
              </Suspense>
            ),
          },
          {
            path: "notes",
            children: [
              {
                index: true,
                element: (
                  <Suspense fallback={<Loader />}>
                    <Notes />
                  </Suspense>
                ),
              },
              {
                path: "create",
                element: (
                  <Suspense fallback={<Loader />}>
                    <CreateNote />
                  </Suspense>
                ),
              },
              {
                path: "edit/:id",
                element: (
                  <Suspense fallback={<Loader />}>
                    <EditNote />
                  </Suspense>
                ),
              },
            ],
          },
        ],
      },
      {
        path: "location",
        children: [
          {
            path: "state",
            element: (
              <Suspense fallback={<Loader />}>
                <State />
              </Suspense>
            ),
          },
          {
            path: "city",
            element: (
              <Suspense fallback={<Loader />}>
                <City />
              </Suspense>
            ),
          },
          {
            path: "pin",
            element: (
              <Suspense fallback={<Loader />}>
                <Pin />
              </Suspense>
            ),
          },
      {
        path: "region",

        children: [
          {
            index: true,
            element: (
              <Suspense fallback={<Loader />}>
                <Region />
              </Suspense>
            ),
          },
          {
            path: "create",
            element: (
              <Suspense fallback={<Loader />}>
                <CreateRegion />
              </Suspense>
            ),
          },
          {
            path: "edit/:id",
            element: (
              <Suspense fallback={<Loader />}>
                <EditRegion />
              </Suspense>
            ),
          },
        ],
      },
        ],
      },
      {
        path: "product",
        children: [
          {
            index: true,
            element: (
              <Suspense fallback={<Loader />}>
                <Product />
              </Suspense>
            ),
          },
          {
            path: "create",
            element: (
              <Suspense fallback={<Loader />}>
                <CreateProduct />
              </Suspense>
            ),
          },
          {
            path: "edit/:id",
            element: (
              <Suspense fallback={<Loader />}>
                <EditProduct />
              </Suspense>
            ),
          },
        ],
      },
      {
        path: "damagebook",
        element: (
          <Suspense fallback={<Loader />}>
            <DamageList />
          </Suspense>
        ),
      },
      {
        path: "influencer",
        children: [
          {
            index: true,
            element: (
              <Suspense fallback={<Loader />}>
                <Influencer />
              </Suspense>
            ),
          },
          {
            path: "create",
            element: (
              <Suspense fallback={<Loader />}>
                <CreateInfluencer />
              </Suspense>
            ),
          },
          {
            path: "edit/:id",
            element: (
              <Suspense fallback={<Loader />}>
                <EditInfluencer />
              </Suspense>
            ),
          },
        ],
      },
      {
        path: "project",
        // element: (
        //   <Suspense fallback={<Loader />}>
        //     <Project />
        //   </Suspense>
        // ),

        children: [
          {
            index: true,
            element: (
              <Suspense fallback={<Loader />}>
                <Project />
              </Suspense>
            ),
          },
          {
            path: "create",
            element: (
              <Suspense fallback={<Loader />}>
                <CreateProject />
              </Suspense>
            ),
          },
          {
            path: "edit/:id",
            element: (
              <Suspense fallback={<Loader />}>
                <EditProject />
              </Suspense>
            ),
          },
        ],
      },
      // {
      //   path: "region",

      //   children: [
      //     {
      //       index: true,
      //       element: (
      //         <Suspense fallback={<Loader />}>
      //           <Region />
      //         </Suspense>
      //       ),
      //     },
      //     {
      //       path: "create",
      //       element: (
      //         <Suspense fallback={<Loader />}>
      //           <CreateRegion />
      //         </Suspense>
      //       ),
      //     },
      //     {
      //       path: "edit/:id",
      //       element: (
      //         <Suspense fallback={<Loader />}>
      //           <EditRegion />
      //         </Suspense>
      //       ),
      //     },
      //   ],
      // },
      {
        path: "salesrequest",
        element: (
          <Suspense fallback={<Loader />}>
            <RequestList />
          </Suspense>
        ),
      },
      {
        path: "branch",
        children: [
          {
            path: "request",
            element: (
              <Suspense fallback={<Loader />}>
                <Request />
              </Suspense>
            ),
          },
          {
            path: "request/create",
            element: (
              <Suspense fallback={<Loader />}>
                <CreateSampleRequest />
              </Suspense>
            ),
          },
          {
            path: "list",
            element: (
              <Suspense fallback={<Loader />}>
                <BranchList />
              </Suspense>
            ),
          },
          {
            path: "create",
            element: (
              <Suspense fallback={<Loader />}>
                <BranchCreate />
              </Suspense>
            ),
          },
          {
            path: "edit/:id",
            element: (
              <Suspense fallback={<Loader />}>
                <BranchEdit />
              </Suspense>
            ),
          },
          {
            path: "stock",
            element: (
              <Suspense fallback={<Loader />}>
                <Stock />
              </Suspense>
            ),
          },
          {
            path: "order",
            element: (
              <Suspense fallback={<Loader />}>
                <OrderList />
              </Suspense>
            ),
          },
          {
            path: "order/details/:id",
            element: (
              <Suspense fallback={<Loader />}>
                <OrderDetails />
              </Suspense>
            ),
          },
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
