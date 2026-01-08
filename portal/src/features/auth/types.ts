import type { ItemStatus, UserType } from "@/lib/types";
export type ImportedUser = {
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
export interface User extends ImportedUser {
  access_token: string;
}

export interface LoginRespons {
  SUCCESS: boolean;
  MESSAGE: User;
}

export interface LoginData {
  email: string;
  password: string;
}
