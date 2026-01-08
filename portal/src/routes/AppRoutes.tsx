import { Suspense, lazy } from "react";
import { createBrowserRouter, RouterProvider } from "react-router-dom";
import Loader from "@/components/fullpage-loader";
import { ProtectedElement } from "@/components/protected-element";
// import { ProtectedElement } from "@/components/protected-element";

// Lazy imports
const Login = lazy(() => import("@/features/auth/pages/Login"));
const Register = lazy(() => import("@/features/auth/pages/Register"));
const Root = lazy(() => import("@/layouts/Root"));
const Home = lazy(() => import("@/features/home/pages"));

// Users
const UserList = lazy(() => import("@/features/users/pages").then((m) => ({ default: m.UserList })));
const UserCreate = lazy(() => import("@/features/users/pages").then((m) => ({ default: m.UserCreate })));
const UserEdit = lazy(() => import("@/features/users/pages").then((m) => ({ default: m.UserEdit })));
const ResetPassowrd = lazy(() => import("@/features/users/pages").then((m) => ({ default: m.ResetPassowrd })));
const Profile = lazy(() => import("@/features/users/pages").then((m) => ({ default: m.Profile })));

// Branch
const BranchList = lazy(() => import("@/features/branche/pages").then((m) => ({ default: m.BranchList })));
const BranchCreate = lazy(() => import("@/features/branche/pages/index").then((m) => ({ default: m.BranchCreate })));
const BranchEdit = lazy(() => import("@/features/branche/pages").then((m) => ({ default: m.BranchEdit })));
const Request = lazy(() => import("@/features/sample-request/pages").then((m) => ({ default: m.Request })));
const Stock = lazy(() => import("@/features/branche/pages").then((m) => ({ default: m.Stock })));
const OrderList = lazy(() => import("@/features/branche/pages").then((m) => ({ default: m.OrderList })));
const OrderDetails = lazy(() => import("@/features/branche/pages").then((m) => ({ default: m.OrderDetails })));
const CreateSampleRequest = lazy(() => import("@/features/sample-request/pages").then((m) => ({ default: m.createSampleRequest })));
const RequestList = lazy(() => import("@/features/sales/pages").then((m) => ({ default: m.requestList })));

// Settings
const General = lazy(() => import("@/features/settings/pages").then((m) => ({ default: m.General })));
const Product = lazy(() => import("@/features/product/pages").then((m) => ({ default: m.Product })));
const EditProduct = lazy(() => import("@/features/product/pages").then((m) => ({ default: m.EditProduct })));
const CreateProduct = lazy(() => import("@/features/product/pages").then((m) => ({ default: m.CreateProduct })));
const Notification = lazy(() => import("@/features/settings/pages").then((m) => ({ default: m.Notification })));
const Notes = lazy(() => import("@/features/settings/pages").then((m) => ({ default: m.Notes })));
const CreateNote = lazy(() => import("@/features/settings/pages").then((m) => ({ default: m.CreateNote })));
const EditNote = lazy(() => import("@/features/settings/pages").then((m) => ({ default: m.EditNote })));

// Influencer
const Influencer = lazy(() => import("@/features/influencer/pages").then((m) => ({ default: m.InfluencerList })));
const CreateInfluencer = lazy(() => import("@/features/influencer/pages").then((m) => ({ default: m.CreateInfluencer })));
const EditInfluencer = lazy(() => import("@/features/influencer/pages").then((m) => ({ default: m.EditInfluencer })));

// Project
const Project = lazy(() => import("@/features/project/pages").then((m) => ({ default: m.Project })));
const EditProject = lazy(() => import("@/features/project/pages").then((m) => ({ default: m.EditProject })));
const CreateProject = lazy(() => import("@/features/project/pages").then((m) => ({ default: m.CreateProject })));

// Region
const Region = lazy(() => import("@/features/region/pages").then((m) => ({ default: m.Region })));
const EditRegion = lazy(() => import("@/features/region/pages").then((m) => ({ default: m.EditRegion })));
const CreateRegion = lazy(() => import("@/features/region/pages").then((m) => ({ default: m.CreateRegion })));

// Location
const State = lazy(() => import("@/features/location/pages").then((m) => ({ default: m.StateLists })));
const City = lazy(() => import("@/features/location/pages").then((m) => ({ default: m.CityLists })));
const Pin = lazy(() => import("@/features/location/pages").then((m) => ({ default: m.PinLists })));

// Damage book
const DamageList = lazy(() => import("@/features/damage/pages").then((m) => ({ default: m.DamageList })));

// Misc
const NotFound = lazy(() => import("@/features/notfound/pages").then((m) => ({ default: m.NotFound })));

// ----------------------------------------------------------------------

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
    element: <ProtectedElement path="/" element={<Root />} />,
    children: [
      { index: true, element: <ProtectedElement path="/" element={<Home />} /> },

      // USERS
      {
        path: "user",
        children: [
          { index: true, element: <ProtectedElement path="user" element={<UserList />} /> },
          { path: "create", element: <ProtectedElement path="user" element={<UserCreate />} /> },
          { path: "edit/:id", element: <ProtectedElement path="user" element={<UserEdit />} /> },
          { path: "reset-password", element: <ResetPassowrd /> },
          { path: "profile", element: <Profile  />},
          // {path: "/login", element: <Suspense fallback={<Loader />}><Login /></Suspense>},
        ],
      },

      // SETTINGS
      {
        path: "settings",
        children: [
          { path: "general", element: <ProtectedElement path="settings/general" element={<General />} /> },
          { path: "notification", element: <ProtectedElement path="settings/general" element={<Notification />} /> },
          {
            path: "notes",
            children: [
              { index: true, element: <ProtectedElement path="settings/general" element={<Notes />} /> },
              { path: "create", element: <ProtectedElement path="settings/general" element={<CreateNote />} /> },
              { path: "edit/:id", element: <ProtectedElement path="settings/general" element={<EditNote />} /> },
            ],
          },
        ],
      },

      // LOCATION
      {
        path: "location",
        children: [
          { path: "state", element: <ProtectedElement path="location/*" element={<State />} /> },
          { path: "city", element: <ProtectedElement path="location/*" element={<City />} /> },
          { path: "pin", element: <ProtectedElement path="location/*" element={<Pin />} /> },
          {
            path: "region",
            children: [
              { index: true, element: <ProtectedElement path="region" element={<Region />} /> },
              { path: "create", element: <ProtectedElement path="region" element={<CreateRegion />} /> },
              { path: "edit/:id", element: <ProtectedElement path="region" element={<EditRegion />} /> },
            ],
          },
        ],
      },

      // PRODUCT
      {
        path: "product",
        children: [
          { index: true, element: <ProtectedElement path="product" element={<Product />} /> },
          { path: "create", element: <ProtectedElement path="product" element={<CreateProduct />} /> },
          { path: "edit/:id", element: <ProtectedElement path="product" element={<EditProduct />} /> },
        ],
      },

      // DAMAGE BOOK
      { path: "damagebook", element: <ProtectedElement path="damagebook" element={<DamageList />} /> },

      // INFLUENCER
      {
        path: "influencer",
        children: [
          { index: true, element: <ProtectedElement path="influencer" element={<Influencer />} /> },
          { path: "create", element: <ProtectedElement path="influencer" element={<CreateInfluencer />} /> },
          { path: "edit/:id", element: <ProtectedElement path="influencer" element={<EditInfluencer />} /> },
        ],
      },

      // PROJECT
      {
        path: "project",
        children: [
          { index: true, element: <ProtectedElement path="project" element={<Project />} /> },
          { path: "create", element: <ProtectedElement path="project" element={<CreateProject />} /> },
          { path: "edit/:id", element: <ProtectedElement path="project" element={<EditProject />} /> },
        ],
      },

      // SALES
      { path: "salesrequest", element: <ProtectedElement path="salesrequest" element={<RequestList />} /> },

      // BRANCH
      {
        path: "branch",
        children: [
          { path: "request", element: <ProtectedElement path="branch/request" element={<Request />} /> },
          { path: "request/create", element: <ProtectedElement path="branch/request/create" element={<CreateSampleRequest />} /> },
          { path: "list", element: <ProtectedElement path="branch/list" element={<BranchList />} /> },
          { path: "create", element: <ProtectedElement path="branch/list" element={<BranchCreate />} /> },
          { path: "edit/:id", element: <ProtectedElement path="branch/list" element={<BranchEdit />} /> },
          { path: "stock", element: <ProtectedElement path="branch/stock" element={<Stock />} /> },
          { path: "order", element: <ProtectedElement path="branch/order" element={<OrderList />} /> },
          { path: "order/details/:id", element: <ProtectedElement path="branch/order" element={<OrderDetails />} /> },
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
