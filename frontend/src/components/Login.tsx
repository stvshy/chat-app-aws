import { useState } from "react";
import "./auth.css";

export default function Login({
                                  onLogin,
                              }: {
    onLogin: (token: string, username: string) => void;
}) {
    const [username, setUsername] = useState("");
    const [password, setPassword] = useState("");
    // Użyj nowej zmiennej środowiskowej dla API autoryzacji
    const authApiUrl = import.meta.env.VITE_AUTH_API_URL;

    const handleLogin = async () => {
        // Sprawdź, czy URL jest zdefiniowany
        if (!authApiUrl) {
            alert("Auth API URL is not configured!");
            return;
        }
        try {
            // Użyj authApiUrl zamiast starego apiUrl/api/auth/login
            const res = await fetch(`${authApiUrl}/login`, {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ username, password }),
            });
            if (res.ok) {
                const responseData = await res.json();
                console.log("Response data:", responseData);
                const token = responseData.idToken;
                onLogin(token, username);
            } else {
                alert("Incorrect login credentials");
            }
        } catch (error) {
            console.error("Login error:", error);
            alert("Error during login.");
        }
    };

    return (
        <div className="card login-card">
            <h2>Sign in</h2>
            <input
                placeholder="Username"
                value={username}
                onChange={(e) => setUsername(e.target.value)}
            />
            <input
                type="password"
                placeholder="Password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
            />
            <button className="send-button" onClick={handleLogin}>
                Login
            </button>
        </div>
    );
}
