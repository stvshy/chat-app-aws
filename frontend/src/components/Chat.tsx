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
    // Dodajemy pole file (może być null lub undefined)
    file?: string | null;
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
    const [file, setFile] = useState<File | null>(null);

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
            if (file) {
                // Przygotowanie danych jako FormData
                const formData = new FormData();
                formData.append("author", username);
                formData.append("content", content);
                formData.append("recipient", recipient);
                formData.append("file", file);

                const res = await fetch("http://localhost:8081/api/messages/with-file", {
                    method: "POST",
                    headers: {
                        Authorization: `Bearer ${token}`, // Nie ustawiamy Content-Type – przeglądarka ustawi boundary
                    },
                    body: formData,
                });

                if (res.ok) {
                    alert("Wiadomość z plikiem wysłana pomyślnie!");
                    // Odśwież widoki wiadomości
                    fetchSentMessages();
                    fetchReceivedMessages();
                    // Wyczyść pola
                    setRecipient("");
                    setContent("");
                    setFile(null);
                } else {
                    const text = await res.text();
                    alert("Błąd wysyłania wiadomości: " + text);
                }
            } else {
                // Jeśli nie ma pliku, wysyłamy standardową wiadomość
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
                    fetchSentMessages();
                    fetchReceivedMessages();
                    setRecipient("");
                    setContent("");
                } else {
                    const text = await res.text();
                    alert("Błąd wysyłania wiadomości: " + text);
                }
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
                    <input
                        type="file"
                        onChange={(e) => setFile(e.target.files ? e.target.files[0] : null)}
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
                                {/* Link do pobrania pliku (jeśli istnieje) */}
                                {msg.file && (
                                    <>
                                        <br />
                                        <strong>Załącznik:</strong>{" "}
                                        <a
                                            href={`http://localhost:8081/api/files/download/${msg.id}`}
                                            target="_blank"
                                            rel="noreferrer"
                                        >
                                            Pobierz plik
                                        </a>
                                    </>
                                )}
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
                                {/* Link do pobrania pliku (jeśli istnieje) */}
                                {msg.file && (
                                    <>
                                        <br />
                                        <strong>Załącznik:</strong>{" "}
                                        <a
                                            href={`http://localhost:8081/api/files/download/${msg.id}`}
                                            target="_blank"
                                            rel="noreferrer"
                                        >
                                            Pobierz plik
                                        </a>
                                    </>
                                )}
                            </li>
                        ))}
                    </ul>
                </div>
            </div>
        </div>
    );
}
