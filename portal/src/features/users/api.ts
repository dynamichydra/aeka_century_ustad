import API from "@/lib/api";
import type { User } from "./types";

export async function getUsers(): Promise<User[] | null> {
  try {
    const response = await API.post("", {
      TYPE: "user",
      TASK: "get",
      DATA: {},
    });
    const {
      data: { SUCCESS, MESSAGE },
    } = response;
    if (SUCCESS) {
      return MESSAGE;
    } else {
      throw new Error(MESSAGE || "Users not found");
    }
  } catch (error) {
    console.log(error);
    throw error;
  }
}

export async function createUsers(data: User): Promise<User[] | null> {
  try {
    const response = await API.post("", {
      TYPE: "user",
      TASK: "set",
      DATA: {
        ...data,
      },
    });
    const {
      data: { SUCCESS, MESSAGE },
    } = response;
    if (SUCCESS) {
      return MESSAGE;
    } else {
      throw new Error(MESSAGE || "Users not found");
    }
  } catch (error) {
    console.log(error);
    throw error;
  }
}