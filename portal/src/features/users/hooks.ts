import { useQuery } from "@tanstack/react-query";
import { getUsers } from "./api";

export function useGetUsers() {
  const {
    data: users,
    isLoading,
    isError,
    isFetching
  } = useQuery({
    queryKey: ["users"],
    queryFn: getUsers,
  });  
  return { users, isLoading, isError, isFetching };
}