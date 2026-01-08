import type { ItemStatus, UserType } from "@/lib/types";

export type User = {
  id: number;
  code: string;
  name: string;
  email: string;
  phone: string;
  pwd: string;
  address: string;
  state: string;
  city: string;
  zip: string;
  created_by: string;
  created_at: string;
  status: ItemStatus;
  type: UserType;
  branch: string[];
};
export type PatchPayload = {
  BACKEND_ACTION: string;
  ID_RESPONSE: string;
  user_id?: number | undefined;
  branch_id?: string;
  id?: string;
  created_by?: number | undefined;
}[];