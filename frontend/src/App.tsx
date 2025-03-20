import { useState } from "react";
import Login from "./components/Login";
import Register from "./components/Register";
import Chat from "./components/Chat";
// @ts-ignore
import "./styles.css";

export default function App() {
    const [token, setToken] = useState("");
    const [username, setUsername] = useState("");

    if(!token) {
        return (
            <div className="container">
                <Register/>
                <Login onLogin={(t,u)=>{setToken(t); setUsername(u)}}/>
            </div>
        );
    }

    return <Chat token={token} username={username}/>;
}
