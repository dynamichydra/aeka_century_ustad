import type { User as ImportedUser } from "@/features/users/types";

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
