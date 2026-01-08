export default function WelcomeBanner() {
  const userName = "Jone Doe";

  return (
    <div className="rounded-2xl flex flex-col justify-center items-center">
      <h2 className="text-2xl font-bold">👋 Welcome back, {userName}!</h2>
      <p className="text-sm opacity-90 mt-1">
        Here’s what’s happening with your branches, orders, and products today.
      </p>
    </div>
  );
}
