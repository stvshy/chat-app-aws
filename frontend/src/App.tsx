import { useState } from "react";
import Login from "./components/Login";
import Register from "./components/Register";
import Chat from "./components/Chat";
import "./styles.css";

export default function App() {
    const [token, setToken] = useState("");
    const [username, setUsername] = useState("");

    if (!token) {
        return (
            <div className="auth-page">
                <div className="container auth-container">
                    <Register />
                    <Login onLogin={(t, u) => { setToken(t); setUsername(u); }} />
                </div>
            </div>
        );
    }

    return (
        <div className="chat-page">
            <Chat token={token} username={username} />
        </div>
    );
}
