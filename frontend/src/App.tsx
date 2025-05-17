// frontend/src/App.tsx
import { useState } from "react";
import Login from "./components/Login";
import Register from "./components/Register";
import Chat from "./components/Chat";
import NotificationsBell from "./components/NotificationsBell"; // IMPORTUJ
import { INotificationRecord } from "./types/types.tsx"; // IMPORTUJ TYP (upewnij się, że ścieżka jest poprawna)
import "./styles.css"; // Możesz użyć App.css lub styles.css dla stylów globalnych aplikacji

export default function App() {
    const [token, setToken] = useState<string>("");
    const [username, setUsername] = useState<string>(""); // To jest nick użytkownika

    // Pobierz URL API notyfikacji ze zmiennych środowiskowych Vite
    const notificationApiUrl = import.meta.env.VITE_NOTIFICATION_API_URL;

    const handleLogin = (t: string, u: string) => {
        setToken(t);
        setUsername(u); // Ustawiamy nick zalogowanego użytkownika
    };

    // Funkcja, która może być wywołana po kliknięciu w element na liście powiadomień
    const handleNotificationItemClick = (record: INotificationRecord) => {
        console.log("Notification item clicked in App.tsx:", record);
        // Tutaj możesz dodać logikę nawigacji do odpowiedniej wiadomości/czatu
        // na podstawie record.relatedEntityId lub record.type
        // Np. jeśli używasz React Router:
        // if (record.type.includes("MESSAGE") && record.relatedEntityId) {
        //   navigate(`/chat/message/${record.relatedEntityId}`);
        // }
    };

    if (!token || !username) { // Sprawdzamy też username dla pewności
        return (
            <div className="auth-page">
                <div className="container auth-container">
                    <Register />
                    <Login onLogin={handleLogin} />
                </div>
            </div>
        );
    }

    return (
        <div className="app-container">
            <header className="app-header">
                <h1>Projekt Chmury Chat</h1>
                {/*
                    Wyświetl dzwonek tylko jeśli mamy token, username i skonfigurowany URL API notyfikacji.
                    Przekazujemy username (nick) do NotificationsBell, aby mógł filtrować
                    powiadomienia dla bieżącego użytkownika, jeśli API /history zwraca powiadomienia
                    dla użytkownika z tokenu, ale chcemy dodatkowo pewność po stronie klienta
                    lub jeśli NotificationRecord.userId to nick.
                */}
                {notificationApiUrl ? (
                    <NotificationsBell
                        token={token}
                        username={username} // Przekazujemy nick zalogowanego użytkownika
                        notificationApiUrl={notificationApiUrl}
                        onNotificationItemClick={handleNotificationItemClick}
                    />
                ) : (
                    <p style={{color: "orange"}}>Notification API URL not configured.</p>
                )}
            </header>
            <main className="app-main">
                {/*
                    Struktura strony czatu może pozostać taka sama lub możesz ją dostosować.
                    Poniżej zakładam, że Chat zajmuje główną część strony.
                */}
                <div className="chat-page-wrapper"> {/* Dodatkowy wrapper, jeśli potrzebny */}
                    <Chat token={token} username={username} />
                </div>
            </main>
            {/* Możesz dodać stopkę, jeśli chcesz */}
            {/* <footer className="app-footer">
                <p>&copy; {new Date().getFullYear()} Your App Name</p>
            </footer> */}
        </div>
    );
}
