import { useEffect, useState } from "react";

function App() {
    const [messages, setMessages] = useState([]);
    const [content, setContent] = useState("");
    const [author, setAuthor] = useState("");

    useEffect(() => {
        fetch("http://localhost:8081/api/messages")
            .then((res) => res.json())
            .then((data) => setMessages(data));
    }, []);

    const handleSend = async () => {
        const newMsg = { content, author };
        await fetch("http://localhost:8081/api/messages", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify(newMsg),
        });
        // Odswież listę
        const res = await fetch("http://localhost:8081/api/messages");
        const data = await res.json();
        setMessages(data);
    };

    return (
        <div>
            <h1>Chat</h1>
            <ul>
                {messages.map((m: any) => (
                    <li key={m.id}>
                        {m.author}: {m.content}
                    </li>
                ))}
            </ul>
            <input
                type="text"
                placeholder="author"
                value={author}
                onChange={(e) => setAuthor(e.target.value)}
            />
            <input
                type="text"
                placeholder="content"
                value={content}
                onChange={(e) => setContent(e.target.value)}
            />
            <button onClick={handleSend}>Send</button>
        </div>
    );
}

export default App;
