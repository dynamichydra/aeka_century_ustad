import { useUser } from "@/hooks/use-user";
import { LoginForm } from "../components/loginFrom";
import logo from "@/assets/centuryply.png";
import { useEffect } from "react";
import { useNavigate } from "react-router";
const Login = () => {
  const navigate = useNavigate();
  const {user,isLoading} = useUser();
  useEffect(() => {
    if (!isLoading && user) {
       if (user.type==='Sales') {
         navigate("/salesrequest", { replace: true });
       }else{
         navigate("/", { replace: true });
       }
    }
  }, [isLoading, user, navigate]);
  return (
    <div className="flex min-h-svh w-full items-center justify-center p-6 md:p-10">
      <div className="w-full max-w-sm">
        <img src={logo} className="w-48 mx-auto mb-10 object-contain"/>
        <LoginForm />
      </div>
    </div>
  );
}

export default Login