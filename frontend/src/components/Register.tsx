import { useState } from "react";
import "./auth.css";

export default function Register() {
    const [username, setUsername] = useState("");
    const [password, setPassword] = useState("");

    const handleRegister = async () => {
        const res = await fetch("http://localhost:8081/api/auth/register", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ username, password }),
        });
        const text = await res.text();
        alert(res.ok ? "Your account has been created!" : "Registration error:" + text);
        setUsername("");
        setPassword("");
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
