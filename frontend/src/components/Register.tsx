import { useState } from "react";
import "./auth.css";

export default function Register() {
    const [username, setUsername] = useState("");
    const [password, setPassword] = useState("");
    // Użyj nowej zmiennej środowiskowej dla API autoryzacji
    const authApiUrl = import.meta.env.VITE_AUTH_API_URL;

    const handleRegister = async () => {
        if (!authApiUrl) {
            alert("Auth API URL is not configured!");
            return;
        }
        try {
            const res = await fetch(`${authApiUrl}/register`, {
                method: "POST",
                headers: {
                    "Content-Type": "application/json",
                    "Accept": "application/json"
                },
                body: JSON.stringify({ username, password }),
                credentials: 'include'  // Dodaj tę linię
            });

            if (!res.ok) {
                const errorText = await res.text();
                throw new Error(`Registration failed: ${errorText}`);
            }

            alert("Your account has been created!");
            setUsername("");
            setPassword("");
        } catch (error) {
            if (error instanceof Error) {
                console.error("Register error:", error);
                alert(`Error during registration: ${error.message}`);
            } else {
                console.error("Register error: Unknown error", error);
                alert("An unknown error occurred during registration.");
            }
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
