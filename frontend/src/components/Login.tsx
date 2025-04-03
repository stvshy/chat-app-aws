import { useState } from "react";
import "./auth.css";

export default function Login({
                                  onLogin,
                              }: {
    onLogin: (token: string, username: string) => void;
}) {
    const [username, setUsername] = useState("");
    const [password, setPassword] = useState("");
    const apiUrl = import.meta.env.VITE_API_URL;
    const handleLogin = async () => {
        const res = await fetch(`http://${apiUrl}/api/auth/login`, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ username, password }),
        });
        if (res.ok) {
            const responseData = await res.json();
            // Zakładamy, że używamy accessToken do dalszych żądań
            const token = responseData.idToken;
            onLogin(token, username);
        } else {
            alert("Incorrect login credentials");
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
