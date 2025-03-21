import { useState } from "react";
import "./auth.css";

export default function Login({
                                  onLogin,
                              }: {
    onLogin: (token: string, username: string) => void;
}) {
    const [username, setUsername] = useState("");
    const [password, setPassword] = useState("");

    const handleLogin = async () => {
        const res = await fetch("http://localhost:8081/api/auth/login", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ username, password }),
        });
        if (res.ok) {
            const { token } = await res.json();
            onLogin(token, username);
        } else alert("Niepoprawne dane");
    };

    return (
        <div className="card login-card">
            <h2>Logowanie</h2>
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
                Zaloguj
            </button>
        </div>
    );
}
