import { useState } from "react";
import "./auth.css";

export default function Register() {
    const [username, setUsername] = useState("");
    const [password, setPassword] = useState("");
    // Użyj nowej zmiennej środowiskowej dla API autoryzacji
    const authApiUrl = import.meta.env.VITE_AUTH_API_URL;

    const handleRegister = async () => {
        // Sprawdź, czy URL jest zdefiniowany
        if (!authApiUrl) {
            alert("Auth API URL is not configured!");
            return;
        }
        try {
            // Użyj authApiUrl zamiast starego apiUrl/api/auth/register
            const res = await fetch(`${authApiUrl}/register`, {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ username, password }),
            });
            const text = await res.text();
            alert(
                res.ok
                    ? "Your account has been created!"
                    : "Registration error:" + text,
            );
            if (res.ok) {
                setUsername("");
                setPassword("");
            }
        } catch (error) {
            console.error("Register error:", error);
            alert("Error during registration.");
        }
    };

    return (
        <div className="card register-card">
            <h2>Create an account</h2>
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
            <button className="send-button" onClick={handleRegister}>
                Register
            </button>
        </div>
    );
}
