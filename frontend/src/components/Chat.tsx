import { useEffect, useState } from "react";
import "./chat.css";
import { FiPlus } from "react-icons/fi";

interface IMessage {
    id: number;
    author: {
        id: number;
        username: string;
        password: string;
    };
    recipient: {
        id: number;
        username: string;
        password: string;
    } | null;
    content: string;
    file?: string | null;
}

interface ChatProps {
    token: string;
    username: string;
}

export default function Chat({ token, username }: ChatProps) {
    const [sentMessages, setSentMessages] = useState<IMessage[]>([]);
    const [receivedMessages, setReceivedMessages] = useState<IMessage[]>([]);

    // Send form states
    const [recipient, setRecipient] = useState("");
    const [content, setContent] = useState("");
    const [file, setFile] = useState<File | null>(null);

    // Controls expansion of sent messages panel
    const [showSent, setShowSent] = useState(false);

    const fetchSentMessages = async () => {
        try {
            const res = await fetch(`http://localhost:8081/api/messages/sent?username=${username}`, {
                headers: { Authorization: `Bearer ${token}` }
            });
            if (res.ok) {
                let data = await res.json();
                // Sort messages: newest first
                data.sort((a: IMessage, b: IMessage) => b.id - a.id);
                setSentMessages(data);
            } else {
                console.error("Error fetching sent messages");
            }
        } catch (error) {
            console.error("Error:", error);
        }
    };

    const fetchReceivedMessages = async () => {
        try {
            const res = await fetch(`http://localhost:8081/api/messages/received?username=${username}`, {
                headers: { Authorization: `Bearer ${token}` }
            });
            if (res.ok) {
                let data = await res.json();
                data.sort((a: IMessage, b: IMessage) => b.id - a.id);
                setReceivedMessages(data);
            } else {
                console.error("Error fetching received messages");
            }
        } catch (error) {
            console.error("Error:", error);
        }
    };

    useEffect(() => {
        fetchSentMessages();
        fetchReceivedMessages();
    }, []);

    const sendMessage = async () => {
        try {
            if (file) {
                const formData = new FormData();
                formData.append("author", username);
                formData.append("content", content);
                formData.append("recipient", recipient);
                formData.append("file", file);
                const res = await fetch("http://localhost:8081/api/messages/with-file", {
                    method: "POST",
                    headers: { Authorization: `Bearer ${token}` },
                    body: formData,
                });
                if (res.ok) {
                    alert("Message with file sent successfully!");
                    fetchSentMessages();
                    fetchReceivedMessages();
                    setRecipient("");
                    setContent("");
                    setFile(null);
                } else {
                    const text = await res.text();
                    alert("Error sending message: " + text);
                }
            } else {
                const body = { author: username, content, recipient };
                const res = await fetch("http://localhost:8081/api/messages", {
                    method: "POST",
                    headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` },
                    body: JSON.stringify(body),
                });
                if (res.ok) {
                    alert("Message sent successfully!");
                    fetchSentMessages();
                    fetchReceivedMessages();
                    setRecipient("");
                    setContent("");
                } else {
                    const text = await res.text();
                    alert("Error sending message: " + text);
                }
            }
        } catch (error) {
            console.error("Error sending message:", error);
            alert("Error sending message!");
        }
    };

    const toggleSent = () => {
        setShowSent(!showSent);
    };

    return (
        <div className="chat-container">
            {/* Left panel: Send message */}
            <div className="chat-left">
                <h2>Welcome, {username}!</h2>
                <div className="send-box">
                    <h3>Send Message</h3>
                    <label>Recipient</label>
                    <input
                        type="text"
                        placeholder="Enter username"
                        value={recipient}
                        onChange={(e) => setRecipient(e.target.value)}
                    />
                    <label>Message</label>
                    <textarea
                        placeholder="Type your message..."
                        value={content}
                        onChange={(e) => setContent(e.target.value)}
                    />
                    <label>Attach file (optional)</label>
                    <div className="file-input-wrapper">
                        <label htmlFor="file-input" className="file-label">
                            {file ? file.name : (<span>No file selected< FiPlus/></span>)}
                        </label>
                        <input
                            type="file"
                            id="file-input"
                            className="file-input"
                            onChange={(e) =>
                                setFile(e.target.files ? e.target.files[0] : null)
                            }
                        />
                    </div>

                    <button className="send-button" onClick={sendMessage}>
                        Send
                    </button>
                </div>
            </div>

            {/* Right panel: Received & Sent messages */}
            <div className="chat-right">
                <div className="received-section">
                    <h3>Received Messages</h3>
                    <div className="message-list">
                        {receivedMessages.map((msg) => (
                            <div key={msg.id} className="message-card">
                                <p>
                                    <strong>{msg.author.username}</strong>
                                </p>
                                <p>
                                    {msg.content}
                                </p>
                                {msg.file && (
                                    <p>
                                        <a
                                            href={`http://localhost:8081/api/files/download/${msg.id}`}
                                            target="_blank"
                                            rel="noreferrer"
                                        >
                                            Download file
                                        </a>
                                    </p>
                                )}
                            </div>
                        ))}
                    </div>
                </div>

                <div className={`sent-section ${showSent ? "expanded" : ""}`}>
                    <h3 onClick={toggleSent} className="collapsible-header">
                        <h3>Sent Messages {showSent ? "▲" : "▼"}</h3>
                    </h3>
                    {showSent && (
                        <div className="message-list">
                            {sentMessages.map((msg) => (
                                <div key={msg.id} className="message-card">
                                    <p>
                                        <strong>{msg.recipient ? msg.recipient.username : "Broadcast"}</strong>
                                    </p>
                                    <p>
                                        {msg.content}
                                    </p>
                                    {msg.file && (
                                        <p>
                                            <a
                                                href={`http://localhost:8081/api/files/download/${msg.id}`}
                                                target="_blank"
                                                rel="noreferrer"
                                            >
                                                Download file
                                            </a>
                                        </p>
                                    )}
                                </div>
                            ))}
                        </div>
                    )}
                </div>
            </div>
        </div>
    );
}
