// frontend/src/App.tsx
import { useState } from "react";
import Login from "./components/Login";
import Register from "./components/Register";
import Chat from "./components/Chat";
import NotificationsBell from "./components/NotificationsBell"; // IMPORTUJ
import { INotificationRecord } from "./types/types";      // IMPORTUJ
import "./styles.css"; // Twój główny plik stylów

export default function App() {
    const [token, setToken] = useState<string>("");
    const [username, setUsername] = useState<string>("");
    const [highlightedMessageId, setHighlightedMessageId] = useState<number | null>(null);
    const [allNotifications, setAllNotifications] = useState<INotificationRecord[]>([]);

    const notificationApiUrl = import.meta.env.VITE_NOTIFICATION_API_URL;

    const handleLogin = (t: string, u: string) => {
        setToken(t);
        setUsername(u);
    };

    const updateNotificationsList = (notifications: INotificationRecord[]) => {
        setAllNotifications(notifications);
    };

    const markNotificationAsReadInService = async (notificationId: string) => {
        if (!notificationApiUrl || !token) return false;
        try {
            const res = await fetch(`${notificationApiUrl}/${notificationId}/mark-as-read`, {
                method: 'POST',
                headers: { Authorization: `Bearer ${token}` },
            });
            if (res.ok) {
                console.log(`Notification ${notificationId} marked as read in notification-service`);
                setAllNotifications(prev =>
                    prev.map(n => n.notificationId === notificationId ? { ...n, readNotification: true } : n)
                );
                return true;
            } else {
                console.error("Error marking notification as read in service:", await res.text());
                return false;
            }
        } catch (error) {
            console.error("Error marking notification as read in service:", error);
            return false;
        }
    };

    const handleNotificationItemClick = (record: INotificationRecord) => {
        console.log("Notification item clicked in App.tsx:", record);
        if (!record.readNotification) {
            markNotificationAsReadInService(record.notificationId);
        }
        if (record.relatedEntityId) {
            setHighlightedMessageId(Number(record.relatedEntityId));
        }
    };

    const handleChatMessageMarkedAsRead = (chatMessageId: number) => {
        console.log(`App: Chat message ${chatMessageId} marked as read. Current allNotifications count: ${allNotifications.length}`);
        const correspondingNotification = allNotifications.find(
            (notif) => {
                console.log(`App: Checking notif ${notif.notificationId}, relatedEntityId: ${notif.relatedEntityId}, read: ${notif.readNotification}`);
                return notif.relatedEntityId === String(chatMessageId) && !notif.readNotification;
            }
        );

        if (correspondingNotification) {
            console.log(`App: Found corresponding notification ${correspondingNotification.notificationId}. Marking it as read.`);
            markNotificationAsReadInService(correspondingNotification.notificationId);
        } else {
            console.log(`App: No unread corresponding notification found for chat message ${chatMessageId}.`);
        }
    };


    // Funkcja do resetowania wyróżnienia, jeśli jest potrzebna
    const clearHighlightedMessage = () => {
        setHighlightedMessageId(null);
    };

    if (!token) {
        return (
            <div className="auth-page"> {/* Twoje oryginalne style dla strony logowania */}
                <div className="container auth-container">
                    <Register />
                    <Login onLogin={handleLogin} />
                </div>
            </div>
        );
    }

    return (
        // Użyj swojej oryginalnej klasy dla strony czatu, np. "chat-page"
        <div className="chat-page">
            {/* Możesz umieścić dzwonek np. w rogu lub nad listą wiadomości w Chat.tsx */}
            {/* Tutaj przykład umieszczenia go nad komponentem Chat */}
            {notificationApiUrl && (
                <div style={{ position: 'absolute', top: '10px', right: '10px', zIndex: 1001 }}> {/* Proste pozycjonowanie */}
                    <NotificationsBell
                        token={token}
                        username={username}
                        notificationApiUrl={notificationApiUrl}
                        onNotificationItemClick={handleNotificationItemClick}
                        notificationsFromApp={allNotifications}
                        onNotificationsFetched={updateNotificationsList}
                        onMarkNotificationAsRead={markNotificationAsReadInService}
                    />
                </div>
            )}
            <Chat
                token={token}
                username={username}
                highlightedMessageId={highlightedMessageId}
                onMessageCardClick={clearHighlightedMessage} // Przekaż funkcję do resetowania
                onChatMessageMarkedAsRead={handleChatMessageMarkedAsRead}
            />
        </div>
    );
}
