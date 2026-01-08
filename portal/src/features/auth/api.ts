import API from "@/lib/api";
import type { LoginData, User } from "./types";
import { LocalStorage } from "@/lib/utils";

export async function Login(loginData: LoginData): Promise<User | null> {
  try {
    const response = await API.post("", {
      TYPE: "auth",
      DATA: {
        username: loginData.email,
        password: loginData.password,
        grant_type: "password",
      },
    });
    const {
      data: { SUCCESS, MESSAGE },
    } = response;
    if (SUCCESS) {
      LocalStorage.set("dm-hotel-mang", MESSAGE);
      return MESSAGE;
    } else {
      throw new Error(MESSAGE || "Login failed");
    }
  } catch (error) {
    console.log(error);
    throw error;
  }
}

export function LogOut() {
  LocalStorage.remove("dm-hotel-mang");
  window.location.href = "/login";
}

export async function getCurrentUser(): Promise<User | null> {
  const data: User = LocalStorage.get("dm-hotel-mang");
  return { ...data, access_token: data.access_token };
}

export async function fetchCurrentUser(): Promise<User | null> {
  const data: User = LocalStorage.get("dm-hotel-mang");
  if (!data || data.access_token == "") return null;
  try {
    const response = await API.post("", {
      TYPE: "user",
      TASK: "get",
      DATA: {
        where: [
          {
            key: "id",
            operator: "id",
            value: data,
          },
        ],
      },
    });
    const {
      data: { SUCCESS, MESSAGE },
    } = response;
    if (SUCCESS) {
      return { ...MESSAGE, access_token: data.access_token };
    } else {
      throw new Error(MESSAGE || "User not found");
    }
  } catch (error) {
    console.log(error);
    throw error;
  }
}
