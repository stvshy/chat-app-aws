import { useState } from "react";

export default function Register() {
    const [username, setUsername] = useState("");
    const [password, setPassword] = useState("");

// W handleRegister:
    const handleRegister = async () => {
        console.log("Attempting registration...");
        const res = await fetch("http://localhost:8081/api/auth/register", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ username, password }),
        });
        console.log("Response status:", res.status);
        const text = await res.text();
        console.log("Response body:", text);

        alert(res.ok ? "Zarejestrowano!" : "Błąd rejestracji");
        setUsername("");
        setPassword("");
    };


    return (
        <div className="card">
            <h2>Rejestracja</h2>
            <input placeholder="Username" value={username} onChange={e=>setUsername(e.target.value)}/>
            <input type="password" placeholder="Password" value={password} onChange={e=>setPassword(e.target.value)}/>
            <button onClick={handleRegister}>Zarejestruj</button>
        </div>
    );
}
