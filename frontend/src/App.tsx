// frontend/src/App.tsx
import { useState /* Dodaj useEffect, jeśli go nie było */ } from "react";
import Login from "./components/Login";
import Register from "./components/Register";
import Chat from "./components/Chat";
import NotificationsBell from "./components/NotificationsBell";
import { INotificationRecord } from "./types/types";
import "./App.css";

export default function App() {
    const [token, setToken] = useState<string>("");
    const [username, setUsername] = useState<string>("");
    const [highlightedMessageId, setHighlightedMessageId] = useState<
        number | null
    >(null);
    const [allNotifications, setAllNotifications] = useState<
        INotificationRecord[]
    >([]);
    const [chatMessagesRefreshKey, setChatMessagesRefreshKey] = useState(0);

    const notificationsApiPrefix = "/api/notifications";
    const chatApiUrl = import.meta.env.VITE_CHAT_API_URL;
    const handleLogin = (t: string, u: string) => {
        setToken(t);
        setUsername(u);
    };

    const updateNotificationsList = (notifications: INotificationRecord[]) => {
        setAllNotifications(notifications);
    };

    const markChatMessageAsReadOnBackend = async (messageId: number) => {
        if (!chatApiUrl || !token) return false;
        try {
            const res = await fetch(
                `${chatApiUrl}/${messageId}/mark-as-read`,
                {
                    method: "POST",
                    headers: { Authorization: `Bearer ${token}` },
                },
            );
            if (res.ok) {
                console.log(
                    `App: Chat message ${messageId} marked as read on backend.`,
                );
                setChatMessagesRefreshKey((prev) => prev + 1);
                return true;
            }
            console.error(
                "App: Error marking chat message as read on backend:",
                await res.text(),
            );
            return false;
        } catch (error) {
            console.error(
                "App: Error marking chat message as read on backend:",
                error,
            );
            return false;
        }
    };

    const markNotificationAsReadInService = async (notificationId: string): Promise<boolean> => {
        // Usunęliśmy sprawdzanie `notificationApiUrl`
        if (!token) return false;
        try {
            // Używamy względnej ścieżki
            const res = await fetch(`${notificationsApiPrefix}/${notificationId}/mark-as-read`, {
                method: "POST",
                headers: { Authorization: `Bearer ${token}` },
            });

            if (res.ok) {
                const updatedNotification =
                    (await res.json()) as INotificationRecord;
                console.log(
                    `App: Notification ${notificationId} marked as read in notification-service. Status: ${updatedNotification.readNotification}`,
                );

                setAllNotifications((prevNotifications) =>
                    prevNotifications.map((n) =>
                        n.notificationId === notificationId
                            ? updatedNotification
                            : n,
                    ),
                );

                // KLUCZOWA ZMIANA: Jeśli powiadomienie zostało pomyślnie oznaczone jako przeczytane
                // i ma powiązane ID wiadomości, oznacz również wiadomość czatu.
                if (
                    updatedNotification.readNotification &&
                    updatedNotification.relatedEntityId
                ) {
                    const messageIdToMark = Number(
                        updatedNotification.relatedEntityId,
                    );
                    console.log(
                        `App: Notification ${notificationId} is related to chat message ${messageIdToMark}. Marking chat message as read.`,
                    );
                    await markChatMessageAsReadOnBackend(messageIdToMark);
                }
                return true;
            } else {
                console.error(
                    `App: Error marking notification ${notificationId} as read in service: ${res.status}`,
                    await res.text(),
                );
                return false;
            }
        } catch (error) {
            console.error(
                `App: Network error or other issue marking notification ${notificationId} as read:`,
                error,
            );
            return false;
        }
    };

    const handleNotificationItemClick = async (
        record: INotificationRecord,
    ) => {
        console.log("App: Notification item clicked:", record);
        let notificationMarkedSuccessfully = false;

        if (!record.readNotification) {
            // markNotificationAsReadInService teraz również zajmie się
            // oznaczeniem powiązanej wiadomości czatu
            notificationMarkedSuccessfully =
                await markNotificationAsReadInService(record.notificationId);
        } else {
            notificationMarkedSuccessfully = true; // Już było przeczytane
        }

        if (notificationMarkedSuccessfully && record.relatedEntityId) {
            const messageIdToHighlight = Number(record.relatedEntityId);
            setHighlightedMessageId(messageIdToHighlight);
            // Oznaczanie wiadomości czatu jako przeczytanej jest już obsługiwane przez
            // markNotificationAsReadInService, więc nie trzeba tu tego powtarzać.
            console.log(
                `App: Highlighting message ${messageIdToHighlight} due to notification click.`,
            );
        }
    };

    const handleChatMessageMarkedAsRead = async (chatMessageId: number) => {
        console.log(
            `App: Chat message ${chatMessageId} was marked as read. Finding corresponding notification.`,
        );
        const correspondingNotification = allNotifications.find(
            (notif) =>
                notif.relatedEntityId === String(chatMessageId) &&
                !notif.readNotification,
        );

        if (correspondingNotification) {
            console.log(
                `App: Found corresponding notification ${correspondingNotification.notificationId}. Marking it as read.`,
            );
            await markNotificationAsReadInService(
                correspondingNotification.notificationId,
            );
        } else {
            console.log(
                `App: No unread corresponding notification found for chat message ${chatMessageId}.`,
            );
        }
    };

    const clearHighlightedMessage = () => {
        setHighlightedMessageId(null);
    };

    if (!token) {
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
                {/*<h1>Projekt Chmury Chat</h1>*/}
                    <NotificationsBell
                        token={token}
                        username={username}
                        // notificationApiUrl={notificationApiUrl}
                        onNotificationItemClick={handleNotificationItemClick}
                        notificationsFromApp={allNotifications}
                        onNotificationsFetched={updateNotificationsList}
                        onMarkNotificationAsRead={
                            markNotificationAsReadInService
                        } // Ta funkcja jest przekazywana do przycisku w panelu
                    />
            </header>
            <main className="app-main">
                <div className="chat-page-wrapper">
                    <Chat
                        token={token}
                        username={username}
                        highlightedMessageId={highlightedMessageId}
                        onMessageCardClick={clearHighlightedMessage}
                        onChatMessageMarkedAsRead={
                            handleChatMessageMarkedAsRead
                        }
                        key={chatMessagesRefreshKey}
                    />
                </div>
            </main>
        </div>
    );
}
