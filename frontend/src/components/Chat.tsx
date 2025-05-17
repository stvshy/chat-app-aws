import {useEffect, useState, useCallback, useRef} from "react";
import "./chat.css";
import { FiPlus, FiCircle } from "react-icons/fi";
import { FiArrowRight, FiChevronDown } from "react-icons/fi";
import { FiChevronUp } from "react-icons/fi";
import { motion, AnimatePresence } from "framer-motion";

// Zaktualizowany interfejs - używamy fileId
interface IMessage {
    id: number;
    authorUsername: string;
    recipientUsername: string | null;
    content: string;
    fileId?: string | null;
    read: boolean; // DODANE: status przeczytania wiadomości
}

interface ChatProps {
    token: string;
    username: string;
}

export default function Chat({ token, username }: ChatProps) {
    const [sentMessages, setSentMessages] = useState<IMessage[]>([]);
    const [receivedMessages, setReceivedMessages] = useState<IMessage[]>([]);
    const [recipient, setRecipient] = useState("");
    const [content, setContent] = useState("");
    const [file, setFile] = useState<File | null>(null);
    const [showSent, setShowSent] = useState(false);

    const chatApiUrl = import.meta.env.VITE_CHAT_API_URL;
    const fileApiUrl = import.meta.env.VITE_FILE_API_URL;

    // Ref dla Intersection Observer
    const observer = useRef<IntersectionObserver | null>(null);
    const observedElements = useRef(new Map<number, HTMLElement>());

    console.log("Token przekazywany do fetch:", token);
    console.log("Chat API URL:", chatApiUrl);
    console.log("File API URL:", fileApiUrl);

    const fetchSentMessages = async () => {
        if (!chatApiUrl) return; // Sprawdź czy URL jest dostępny
        try {
            // Użyj chatApiUrl
            const res = await fetch(
                `${chatApiUrl}/sent?username=${username}`, // USUNIĘTO /messages
                { headers: { Authorization: `Bearer ${token}` } }
            );
            if (res.ok) {
                let data = await res.json();
                data.sort((a: IMessage, b: IMessage) => b.id - a.id);
                setSentMessages(data);
            } else {
                console.error("Error fetching sent messages:", res.statusText);
            }
        } catch (error) {
            console.error("Error fetching sent messages:", error);
        }
    };

    const fetchReceivedMessages = async () => {
        if (!chatApiUrl) return; // Sprawdź czy URL jest dostępny
        try {
            const res = await fetch(
                `${chatApiUrl}/received?username=${username}`, // USUNIĘTO /messages
                { headers: { Authorization: `Bearer ${token}` } }
            );
            if (res.ok) {
                let data = await res.json();
                data.sort((a: IMessage, b: IMessage) => b.id - a.id);
                setReceivedMessages(data);
            } else {
                console.error(
                    "Error fetching received messages:",
                    res.statusText,
                );
            }
        } catch (error) {
            console.error("Error fetching received messages:", error);
        }
    };

    // Funkcja do oznaczania wiadomości jako przeczytanej
    const markMessageAsRead = async (messageId: number) => {
        if (!chatApiUrl) return;
        try {
            const res = await fetch(
                `${chatApiUrl}/${messageId}/mark-as-read`, // Używamy ID wiadomości
                {
                    method: "POST",
                    headers: {
                        Authorization: `Bearer ${token}`,
                        "Content-Type": "application/json", // Chociaż ciało jest puste, dobry zwyczaj
                    },
                },
            );
            if (res.ok) {
                console.log(`Message ${messageId} marked as read`);
                // Zaktualizuj stan receivedMessages, aby odzwierciedlić zmianę
                setReceivedMessages((prevMessages) =>
                    prevMessages.map((msg) =>
                        msg.id === messageId ? { ...msg, read: true } : msg,
                    ),
                );
            } else {
                const errorText = await res.text();
                console.error(
                    `Error marking message ${messageId} as read:`,
                    errorText,
                );
            }
        } catch (error) {
            console.error(
                `Error marking message ${messageId} as read:`,
                error,
            );
        }
    };

    // Callback dla Intersection Observer
    const handleIntersection = useCallback(
        (entries: IntersectionObserverEntry[]) => {
            entries.forEach((entry) => {
                if (entry.isIntersecting) {
                    const messageId = Number(
                        (entry.target as HTMLElement).dataset.messageId,
                    );
                    const message = receivedMessages.find(
                        (msg) => msg.id === messageId,
                    );
                    if (message && !message.read) {
                        markMessageAsRead(messageId);
                        // Opcjonalnie: odłącz obserwatora od tego elementu po oznaczeniu
                        // observer.current?.unobserve(entry.target);
                        // observedElements.current.delete(messageId);
                    }
                }
            });
        },
        [receivedMessages, token, chatApiUrl], // Zależności useCallback
    );
    // Inicjalizacja Intersection Observer
    useEffect(() => {
        observer.current = new IntersectionObserver(handleIntersection, {
            root: null, // viewport
            rootMargin: "0px",
            threshold: 0.5, // 50% elementu musi być widoczne
        });

        return () => {
            observer.current?.disconnect();
            observedElements.current.clear();
        };
    }, [handleIntersection]); // Uruchom ponownie, jeśli handleIntersection się zmieni

    // Obserwuj nowe elementy wiadomości
    useEffect(() => {
        const currentObserver = observer.current;
        if (currentObserver) {
            receivedMessages.forEach((msg) => {
                if (!msg.read) {
                    const element = document.getElementById(`msg-${msg.id}`);
                    if (element && !observedElements.current.has(msg.id)) {
                        currentObserver.observe(element);
                        observedElements.current.set(msg.id, element);
                    }
                } else {
                    // Jeśli wiadomość jest już przeczytana, upewnij się, że nie jest obserwowana
                    const element = observedElements.current.get(msg.id);
                    if (element) {
                        currentObserver.unobserve(element);
                        observedElements.current.delete(msg.id);
                    }
                }
            });
        }
        // Cleanup dla elementów, które mogły zostać usunięte z listy
        // (nie jest to konieczne, jeśli lista tylko rośnie lub jest całkowicie zastępowana)
    }, [receivedMessages]); // Uruchom ponownie, gdy receivedMessages się zmieni
    useEffect(() => {
        fetchSentMessages();
        fetchReceivedMessages();
        // Dodaj chatApiUrl jako zależność, aby odświeżyć, gdyby się zmienił (choć to rzadkie)
    }, [chatApiUrl, username, token]);

    const sendMessage = async () => {
        // Sprawdź dostępność URL-i
        if (!chatApiUrl || !fileApiUrl) {
            alert("API URLs are not configured!");
            return;
        }

        let fileIdentifier: string | null = null;

        try {
            // Krok 1: Jeśli jest plik, wyślij go do file-service
            if (file) {
                const fileFormData = new FormData();
                fileFormData.append("file", file);
                // file-service /upload oczekuje teraz nazwy użytkownika w parametrze
                // fileFormData.append("username", username); // Można też pobrać z tokenu w backendzie

                const fileRes = await fetch(`${fileApiUrl}/upload`, {
                    method: "POST",
                    headers: {
                        // Content-Type jest ustawiany automatycznie przez przeglądarkę dla FormData
                        Authorization: `Bearer ${token}`,
                    },
                    body: fileFormData,
                });

                if (fileRes.ok) {
                    const fileData = await fileRes.json();
                    fileIdentifier = fileData.fileId; // Odczytaj fileId z odpowiedzi file-service
                    if (!fileIdentifier) {
                        throw new Error("fileId not found in file service response");
                    }
                    console.log("File uploaded successfully, fileId:", fileIdentifier);
                } else {
                    const errorText = await fileRes.text();
                    console.error("Error uploading file:", errorText);
                    alert("Error uploading file: " + errorText);
                    return; // Przerwij wysyłanie wiadomości, jeśli upload pliku się nie powiódł
                }
            }

            // Krok 2: Wyślij wiadomość (z fileId lub bez) do chat-service
            const messageBody: {
                author: string;
                content: string;
                recipient: string;
                fileId?: string | null; // Zmieniono klucz z 'file' na 'fileId'
            } = {
                author: username,
                content,
                recipient,
            };
            if (fileIdentifier) {
                messageBody.fileId = fileIdentifier; // Dodaj fileId, jeśli istnieje
            }

            const msgRes = await fetch(chatApiUrl, { // Użyj bezpośrednio chatApiUrl, który już jest /api/messages
                method: "POST",
                headers: {
                    "Content-Type": "application/json",
                    Authorization: `Bearer ${token}`,
                },
                body: JSON.stringify(messageBody),
            });

            if (msgRes.ok) {
                alert("Message sent successfully!");
                // Odśwież wiadomości i wyczyść formularz
                fetchSentMessages();
                fetchReceivedMessages();
                setRecipient("");
                setContent("");
                setFile(null); // Wyczyść wybrany plik
            } else {
                const errorText = await msgRes.text();
                console.error("Error sending message:", errorText);
                alert("Error sending message: " + errorText);
            }
        } catch (error) {
            console.error("Error sending message or file:", error);
            alert("Error sending message!");
        }
    };

    const toggleSent = () => {
        setShowSent(!showSent);
    };
    return (
        <div className="chat-container">
            <div className="chat-left">
                {/* ... (bez zmian) ... */}
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
                            {file ? (
                                file.name
                            ) : (
                                <span>
                                    No file selected
                                    <FiPlus />
                                </span>
                            )}
                        </label>
                        <input
                            type="file"
                            id="file-input"
                            className="file-input"
                            onChange={(e) =>
                                setFile(
                                    e.target.files ? e.target.files[0] : null,
                                )
                            }
                        />
                    </div>
                    <div className="send-button-container">
                        <button className="send-button" onClick={sendMessage}>
                            Send <FiArrowRight className="send-arrow" />
                        </button>
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
                                    id={`msg-${msg.id}`} // ID dla Intersection Observer
                                    className="message-card"
                                    data-message-id={msg.id} // Data attribute dla Intersection Observer
                                >
                                    <p className="message-author">
                                        <strong>{msg.authorUsername}</strong>
                                        {!msg.read && ( // Wyświetl kółko, jeśli nieprzeczytana
                                            <FiCircle
                                                className="unread-indicator"
                                                size={10}
                                                color="white"
                                                fill="white"
                                            />
                                        )}
                                    </p>
                                    <p
                                        className={`message-content ${
                                            !msg.read ? "unread-content" : ""
                                        }`} // Klasa dla pogrubienia
                                    >
                                        {msg.content}
                                    </p>
                                    {msg.fileId && fileApiUrl && (
                                        <p>
                                            <a
                                                href={`${fileApiUrl}/download/${msg.fileId}`}
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

                    {/* ... (sekcja sent messages bez zmian) ... */}
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
                                    <div
                                        className="sent-header"
                                        onClick={toggleSent}
                                    >
                                        <span>Sent Messages</span>
                                        <FiChevronDown
                                            className="sent-icon down"
                                            size={14}
                                        />
                                    </div>
                                    <div className="message-list sent-message-list">
                                        {sentMessages.map((msg) => (
                                            <div
                                                key={msg.id}
                                                className="message-card sent-message-card"
                                            >
                                                <p>
                                                    <strong>
                                                        {msg.recipientUsername
                                                            ? msg.recipientUsername
                                                            : "Broadcast"}
                                                    </strong>
                                                </p>
                                                <p>{msg.content}</p>
                                                {msg.fileId && fileApiUrl && (
                                                    <p>
                                                        <a
                                                            href={`${fileApiUrl}/download/${msg.fileId}`}
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
                            </motion.div>
                        )}
                    </AnimatePresence>

                    {!showSent && (
                        <button
                            onClick={toggleSent}
                            className="sent-toggle-button"
                        >
                            <span>
                                Sent Messages{" "}
                                <FiChevronUp
                                    className="sent-icon up"
                                    size={14}
                                />
                            </span>
                        </button>
                    )}
                </div>
            </div>
        </div>
    );
}