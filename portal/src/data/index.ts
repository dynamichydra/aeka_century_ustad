export type ProductStock = {
  id: number;
  branch_id: number;
  branch_name: string;
  sku: string;
  quantity: number;
  min_stock_label: number;
  avalable_stock: number;
  sales_request: number;
  on_production: number;
  image?: string;
};
 type OrderRequest = {
  id: number;
  request_by: string;
  request_for: string;
  total: number;
  project_details: string;
  created_at: string;
};

export const sample_request: OrderRequest[] = [
  {
    id: 1,
    request_by: "Helga Kelso",
    request_for: "Elisha Riping",
    total: 7,
    project_details: "Cervicitis and endocervicitis",
    created_at: "2025-07-23 07:15:38",
  },
  {
    id: 2,
    request_by: "Fax Bordman",
    request_for: "Delly Stratford",
    total: 3,
    project_details: "Gonococcal prostatitis, chronic",
    created_at: "2024-09-13 15:23:08",
  },
  {
    id: 3,
    request_by: "Ealasaid Evanson",
    request_for: "Sandy Earsman",
    total: 10,
    project_details: "Anomalies of cerebrovascular system",
    created_at: "2025-03-12 09:44:24",
  },
  {
    id: 4,
    request_by: "Flin Fellibrand",
    request_for: "Noelyn Aubery",
    total: 8,
    project_details:
      "Menstrual migraine, without mention of intractable migraine with status migrainosus",
    created_at: "2025-03-14 04:19:20",
  },
  {
    id: 5,
    request_by: "Gannon Juszczyk",
    request_for: "Carlos Manns",
    total: 9,
    project_details: "Unspecified infectious and parasitic diseases",
    created_at: "2025-01-07 18:47:03",
  },
  {
    id: 6,
    request_by: "Vick Ravenshear",
    request_for: "Sonni Yurivtsev",
    total: 7,
    project_details: "Bereavement, uncomplicated",
    created_at: "2025-01-29 11:46:39",
  },
  {
    id: 7,
    request_by: "Flora Gogie",
    request_for: "Thacher Kaye",
    total: 3,
    project_details: "Atony of bladder",
    created_at: "2025-04-25 02:12:59",
  },
  {
    id: 8,
    request_by: "Vina Romanin",
    request_for: "Henry Feild",
    total: 3,
    project_details: "Torticollis, unspecified",
    created_at: "2025-04-15 15:59:50",
  },
  {
    id: 9,
    request_by: "Kiri Isley",
    request_for: "Sancho Jillings",
    total: 9,
    project_details:
      "Isolated tracheal or bronchial tuberculosis, bacteriological or histological examination not done",
    created_at: "2024-11-12 01:07:49",
  },
  {
    id: 10,
    request_by: "Ermina Pigny",
    request_for: "Reynold Boake",
    total: 5,
    project_details: "Immune thrombocytopenic purpura",
    created_at: "2025-08-17 23:01:19",
  },
];
export const stock_report: ProductStock[] = [
  {
    id: 1,
    branch_id: 101,
    branch_name: "Main Warehouse",
    sku: "SOFA-001",
    quantity: 25,
    min_stock_label: 5,
    avalable_stock: 20,
    sales_request: 3,
    on_production: 10,
    image:
      "https://images.unsplash.com/photo-1698417931857-23a611285438?q=80&w=2070&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D",
  },
  {
    id: 2,
    branch_id: 101,
    branch_name: "Main Warehouse",
    sku: "TABLE-002",
    quantity: 40,
    min_stock_label: 8,
    avalable_stock: 35,
    sales_request: 2,
    on_production: 5,
    image: "https://images.unsplash.com/photo-1555041469-a586c61ea9bc",
  },
  {
    id: 3,
    branch_id: 102,
    branch_name: "City Outlet",
    sku: "CHAIR-003",
    quantity: 20,
    min_stock_label: 20,
    avalable_stock: 100,
    sales_request: 15,
    on_production: 30,
    image: "https://images.unsplash.com/photo-1505691938895-1758d7feb511",
  },
  {
    id: 4,
    branch_id: 102,
    branch_name: "City Outlet",
    sku: "DESK-004",
    quantity: 15,
    min_stock_label: 3,
    avalable_stock: 10,
    sales_request: 1,
    on_production: 5,
    image:
      "https://images.unsplash.com/photo-1680503397107-475907e4f3e3?q=80&w=1170&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D",
  },
  {
    id: 5,
    branch_id: 103,
    branch_name: "East Depot",
    sku: "BED-005",
    quantity: 10,
    min_stock_label: 2,
    avalable_stock: 8,
    sales_request: 1,
    on_production: 4,
    image:
      "https://images.unsplash.com/photo-1532588213355-52317771cce6?q=80&w=1074&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D",
  },
  {
    id: 6,
    branch_id: 103,
    branch_name: "East Depot",
    sku: "CABINET-006",
    quantity: 18,
    min_stock_label: 4,
    avalable_stock: 15,
    sales_request: 2,
    on_production: 6,
    image:
      "https://plus.unsplash.com/premium_photo-1689609949921-6b2529511e38?q=80&w=1171&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D",
  },
  {
    id: 7,
    branch_id: 104,
    branch_name: "West Hub",
    sku: "WARDROBE-007",
    quantity: 6,
    min_stock_label: 1,
    avalable_stock: 5,
    sales_request: 1,
    on_production: 2,
    image:
      "https://images.unsplash.com/photo-1604578762246-41134e37f9cc?q=80&w=735&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D",
  },
  {
    id: 8,
    branch_id: 104,
    branch_name: "West Hub",
    sku: "BOOKSHELF-008",
    quantity: 22,
    min_stock_label: 4,
    avalable_stock: 20,
    sales_request: 3,
    on_production: 6,
    image:
      "https://plus.unsplash.com/premium_photo-1683121285611-73d0d38d57a9?q=80&w=1075&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D",
  },
  {
    id: 9,
    branch_id: 105,
    branch_name: "Downtown Store",
    sku: "DINING-009",
    quantity: 12,
    min_stock_label: 2,
    avalable_stock: 9,
    sales_request: 2,
    on_production: 4,
    image: "https://images.unsplash.com/photo-1540574163026-643ea20ade25",
  },
  {
    id: 10,
    branch_id: 105,
    branch_name: "Downtown Store",
    sku: "COFFEE-010",
    quantity: 22,
    min_stock_label: 10,
    avalable_stock: 45,
    sales_request: 5,
    on_production: 10,
    image:
      "https://images.unsplash.com/photo-1600121848594-d8644e57abab?q=80&w=1170&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D",
  },
];
