// frontend/src/components/Chat.tsx
import { useEffect, useState } from "react"; // Usunięto useCallback, useRef
import "./chat.css";
import { FiPlus, FiCircle, FiCheckSquare, FiArrowRight, FiChevronDown, FiChevronUp } from "react-icons/fi";
import { motion, AnimatePresence } from "framer-motion";
import { IMessage } from '../types/types'; // Upewnij się, że ścieżka jest poprawna

interface ChatProps {
    token: string;
    username: string;
    highlightedMessageId?: number | null; // Przyjmujemy ten prop
    onMessageCardClick?: (messageId: number) => void; // Do resetowania highlightu
    onChatMessageMarkedAsRead?: (messageId: number) => void; // Do powiadomienia App.tsx
}

export default function Chat({
                                 token,
                                 username,
                                 highlightedMessageId,
                                 onMessageCardClick,
                                 onChatMessageMarkedAsRead,
                             }: ChatProps) {
    const [sentMessages, setSentMessages] = useState<IMessage[]>([]);
    const [receivedMessages, setReceivedMessages] = useState<IMessage[]>([]);
    const [recipient, setRecipient] = useState("");
    const [content, setContent] = useState("");
    const [file, setFile] = useState<File | null>(null);
    const [showSent, setShowSent] = useState(false);

    const chatApiUrl = import.meta.env.VITE_CHAT_API_URL;
    const fileApiUrlPrefix = "/api/files";

    // Usunięto logikę IntersectionObserver

    const fetchSentMessages = async () => {
        if (!chatApiUrl) return;
        try {
            const res = await fetch(`${chatApiUrl}/sent?username=${username}`, {
                headers: { Authorization: `Bearer ${token}` },
            });
            if (res.ok) {
                const data = (await res.json()) as IMessage[];
                data.sort((a, b) => b.id - a.id);
                setSentMessages(data);
            } else {
                console.error("Error fetching sent messages:", res.statusText);
            }
        } catch (error) {
            console.error("Error fetching sent messages:", error);
        }
    };

    const fetchReceivedMessages = async () => {
        if (!chatApiUrl) return;
        try {
            const res = await fetch(`${chatApiUrl}/received?username=${username}`, {
                headers: { Authorization: `Bearer ${token}` },
            });
            if (res.ok) {
                const data = (await res.json()) as IMessage[];
                data.sort((a, b) => b.id - a.id);
                setReceivedMessages(data);
            } else {
                console.error("Error fetching received messages:", res.statusText);
            }
        } catch (error) {
            console.error("Error fetching received messages:", error);
        }
    };

    // Funkcja do oznaczania wiadomości jako przeczytanej w chat-service
    const handleMarkMessageAsReadInChat = async (messageId: number) => {
        if (!chatApiUrl) return;
        const message = receivedMessages.find(msg => msg.id === messageId);
        if (message && message.read) {
            return; // Już przeczytana
        }
        try {
            const res = await fetch(`${chatApiUrl}/${messageId}/mark-as-read`, {
                method: "POST",
                headers: {
                    Authorization: `Bearer ${token}`,
                    "Content-Type": "application/json",
                },
            });
            if (res.ok) {
                console.log(`Message ${messageId} marked as read in chat-service`);
                setReceivedMessages((prevMessages) =>
                    prevMessages.map((msg) =>
                        msg.id === messageId ? { ...msg, read: true } : msg,
                    ),
                );
                if (onChatMessageMarkedAsRead) {
                    onChatMessageMarkedAsRead(messageId);
                }
            } else {
                console.error(`Error marking message ${messageId} as read:`, await res.text());
            }
        } catch (error) {
            console.error(`Error marking message ${messageId} as read:`, error);
        }
    };

    useEffect(() => {
        fetchSentMessages();
        fetchReceivedMessages();
    }, [chatApiUrl, username, token]); // chatApiUrl może się ładować z opóźnieniem

    const sendMessage = async () => {
        if (!chatApiUrl) {
            alert("Chat API URL is not configured!");
            return;
        }
        let fileIdentifier: string | null = null;
        try {
            if (file) {
                const fileFormData = new FormData();
                fileFormData.append("file", file);
                // Używamy względnej ścieżki do file-service (ALB)
                const fileRes = await fetch(`${fileApiUrlPrefix}/upload`, {
                    method: "POST",
                    headers: { Authorization: `Bearer ${token}` },
                    body: fileFormData,
                });
                if (fileRes.ok) {
                    const fileData = await fileRes.json();
                    fileIdentifier = fileData.fileId;
                } else {
                    const errorText = await fileRes.text();
                    alert("Error uploading file: " + errorText);
                    return;
                }
            }
            const messageBody = { author: username, content, recipient, fileId: fileIdentifier };
            // Używamy pełnego URL-a z API Gateway
            const msgRes = await fetch(chatApiUrl, {
                method: "POST",
                headers: {
                    "Content-Type": "application/json",
                    Authorization: `Bearer ${token}`,
                },
                body: JSON.stringify(messageBody),
            });
            if (msgRes.ok) {
                alert("Message sent successfully!");
                fetchSentMessages();
                fetchReceivedMessages();
                setRecipient("");
                setContent("");
                setFile(null);
            } else {
                const errorText = await msgRes.text();
                alert("Error sending message: " + errorText);
            }
        } catch (error) {
            console.error("Error sending message or file:", error);
            alert("Error sending message!");
        }
    };

    const toggleSent = () => setShowSent(!showSent);

    return (
        // Twoja oryginalna struktura .chat-container
        <div className="chat-container">
            <div className="chat-left">
                <h2>Welcome, {username}!</h2>
                <div className="send-box">
                    <h3>Send Message</h3>
                    <label style={{ textAlign: 'left' }}>Recipient</label>
                    <input type="text" placeholder="Enter username" value={recipient} onChange={(e) => setRecipient(e.target.value)} />
                    <label style={{ textAlign: 'left' }}>Message</label>                    <textarea placeholder="Type your message..." value={content} onChange={(e) => setContent(e.target.value)} />
                    <label style={{ textAlign: 'left' }}>Attach file (optional)</label>
                    <div className="file-input-wrapper">
                        <label htmlFor="file-input" className="file-label">
                            {file ? file.name : <span>No file selected <FiPlus /></span>}
                        </label>
                        <input type="file" id="file-input" className="file-input" onChange={(e) => setFile(e.target.files ? e.target.files[0] : null)} />
                    </div>
                    <div className="send-button-container">
                        <button className="send-button" onClick={sendMessage}>Send <FiArrowRight className="send-arrow" /></button>
                    </div>
                </div>
            </div>

            <div className="chat-right">
                <div className="messages-wrapper">
                    <div className="received-section">
                        <h3>Received Messages</h3>
                        <div className="message-list">
                            {receivedMessages.map((msg) => (
                                <div
                                    key={msg.id}
                                    className={`message-card ${msg.id === highlightedMessageId ? 'highlighted-message' : ''}`}
                                    onClick={() => {
                                        if (onMessageCardClick) {
                                            onMessageCardClick(msg.id);
                                        }
                                        // Opcjonalnie: jeśli kliknięcie w kartę wiadomości ma ją też oznaczyć jako przeczytaną
                                        // if (!msg.read) {
                                        //    handleMarkMessageAsReadInChat(msg.id);
                                        // }
                                    }}
                                >
                                    <div className="message-header"> {/* Dodatkowy div dla flexbox */}
                                        <p className="message-author">
                                            <strong>{msg.authorUsername}</strong>
                                            {!msg.read && (
                                                <FiCircle className="unread-indicator-chat" size={10} color="white" fill="white" />
                                            )}
                                        </p>
                                        {!msg.read && (
                                            <button
                                                className="mark-read-button-chat"
                                                onClick={(e) => {
                                                    e.stopPropagation(); // Zapobiegaj kliknięciu w message-card
                                                    handleMarkMessageAsReadInChat(msg.id);
                                                }}
                                                title="Mark as read"
                                            >
                                                <FiCheckSquare size={18} />
                                            </button>
                                        )}
                                    </div>
                                    <p className={`message-content ${!msg.read ? "unread-content" : ""}`}>
                                        {msg.content}
                                    </p>
                                    {msg.fileId && (
                                        <p>
                                            <a href={`${fileApiUrlPrefix}/download/${msg.fileId}`} target="_blank" rel="noreferrer">
                                                Download file
                                            </a>
                                        </p>
                                    )}
                                </div>
                            ))}
                        </div>
                    </div>
                    {/* Sekcja wysłanych wiadomości bez zmian */}
                    <AnimatePresence>
                        {showSent && (
                            <motion.div
                                initial={{ y: "100%", opacity: 0 }}
                                animate={{ y: 0, opacity: 1 }}
                                exit={{ y: "100%", opacity: 0 }}
                                transition={{ duration: 0.35 }}
                                className="sent-section-wrapper"
                            >
                                <div className="sent-panel">
                                    <div className="sent-header" onClick={toggleSent}>
                                        <span>Sent Messages</span>
                                        <FiChevronDown className="sent-icon down" size={14} />
                                    </div>
                                    <div className="message-list sent-message-list">
                                        {sentMessages.map((msg) => (
                                            <div key={msg.id} className="message-card sent-message-card">
                                                <p><strong>{msg.recipientUsername || "Broadcast"}</strong></p>
                                                <p>{msg.content}</p>
                                                {msg.fileId && (
                                                    <p><a href={`${fileApiUrlPrefix}/download/${msg.fileId}`} target="_blank" rel="noreferrer">Download file</a></p>
                                                )}
                                            </div>
                                        ))}
                                    </div>
                                </div>
                            </motion.div>
                        )}
                    </AnimatePresence>
                    {!showSent && (
                        <button onClick={toggleSent} className="sent-toggle-button">
                            <span>Sent Messages <FiChevronUp className="sent-icon up" size={14} /></span>
                        </button>
                    )}
                </div>
            </div>
        </div>
    );
}
