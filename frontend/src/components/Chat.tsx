import { useEffect, useState } from "react";

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
}

// Definiujemy propsy, które przychodzą z rodzica (App)
interface ChatProps {
    token: string;
    username: string;
}

export default function Chat({ token, username }: ChatProps) {
    // Stany na przechowanie list wiadomości
    const [sentMessages, setSentMessages] = useState<IMessage[]>([]);
    const [receivedMessages, setReceivedMessages] = useState<IMessage[]>([]);

    // Stany do wysyłania nowej wiadomości
    const [recipient, setRecipient] = useState("");
    const [content, setContent] = useState("");

    // Funkcja do pobrania wysłanych wiadomości
    const fetchSentMessages = async () => {
        try {
            const res = await fetch(
                `http://localhost:8081/api/messages/sent?username=${username}`,
                {
                    headers: {
                        Authorization: `Bearer ${token}`,
                    },
                }
            );
            if (res.ok) {
                const data = await res.json();
                setSentMessages(data);
            } else {
                console.error("Błąd podczas pobierania wysłanych wiadomości");
            }
        } catch (error) {
            console.error("Błąd: ", error);
        }
    };

    // Funkcja do pobrania odebranych wiadomości
    const fetchReceivedMessages = async () => {
        try {
            const res = await fetch(
                `http://localhost:8081/api/messages/received?username=${username}`,
                {
                    headers: {
                        Authorization: `Bearer ${token}`,
                    },
                }
            );
            if (res.ok) {
                const data = await res.json();
                setReceivedMessages(data);
            } else {
                console.error("Błąd podczas pobierania odebranych wiadomości");
            }
        } catch (error) {
            console.error("Błąd: ", error);
        }
    };

    // Wywołujemy pobranie wiadomości po załadowaniu komponentu
    useEffect(() => {
        fetchSentMessages();
        fetchReceivedMessages();
    }, []);

    // Funkcja do wysyłania nowej wiadomości
    const sendMessage = async () => {
        try {
            const body = {
                author: username,
                content: content,
                recipient: recipient,
            };
            const res = await fetch("http://localhost:8081/api/messages", {
                method: "POST",
                headers: {
                    "Content-Type": "application/json",
                    Authorization: `Bearer ${token}`,
                },
                body: JSON.stringify(body),
            });

            if (res.ok) {
                alert("Wiadomość wysłana pomyślnie!");
                // Po wysłaniu odśwież widoki
                fetchSentMessages();
                fetchReceivedMessages();

                // Wyczyść pola
                setRecipient("");
                setContent("");
            } else {
                const text = await res.text();
                alert("Błąd wysyłania wiadomości: " + text);
            }
        } catch (error) {
            console.error("Błąd wysyłania wiadomości:", error);
            alert("Błąd wysyłania wiadomości!");
        }
    };

    return (
        <div className="chat-container">
            <h2>Witaj, {username}!</h2>
            <div className="chat-sections">
                {/* Sekcja wysyłania nowej wiadomości */}
                <div className="chat-section">
                    <h3>Wyślij wiadomość</h3>
                    <input
                        type="text"
                        placeholder="Odbiorca (nickname)"
                        value={recipient}
                        onChange={(e) => setRecipient(e.target.value)}
                    />
                    <textarea
                        placeholder="Treść wiadomości"
                        value={content}
                        onChange={(e) => setContent(e.target.value)}
                    />
                    <button onClick={sendMessage}>Wyślij</button>
                </div>

                {/* Sekcja odebranych wiadomości */}
                <div className="chat-section">
                    <h3>Odebrane wiadomości</h3>
                    <button onClick={fetchReceivedMessages}>Odśwież</button>
                    <ul>
                        {receivedMessages.map((msg) => (
                            <li key={msg.id}>
                                <strong>Od:</strong> {msg.author.username} <br />
                                <strong>Treść:</strong> {msg.content}
                            </li>
                        ))}
                    </ul>
                </div>

                {/* Sekcja wysłanych wiadomości */}
                <div className="chat-section">
                    <h3>Wysłane wiadomości</h3>
                    <button onClick={fetchSentMessages}>Odśwież</button>
                    <ul>
                        {sentMessages.map((msg) => (
                            <li key={msg.id}>
                                <strong>Do:</strong>{" "}
                                {msg.recipient ? msg.recipient.username : "Broadcast"} <br />
                                <strong>Treść:</strong> {msg.content}
                            </li>
                        ))}
                    </ul>
                </div>
            </div>
        </div>
    );
}
