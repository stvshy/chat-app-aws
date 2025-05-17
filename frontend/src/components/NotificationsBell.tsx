import React, { useState, useEffect, useRef } from 'react';
import { FiBell } from 'react-icons/fi';
import NotificationsPanel from './NotificationsPanel';
import { INotificationRecord } from '../types/types.tsx';
import './notifications.css'; // Ten sam plik CSS

interface NotificationsBellProps {
    token: string;
    username: string; // Nick zalogowanego użytkownika
    notificationApiUrl: string;
    onNotificationItemClick?: (record: INotificationRecord) => void; // Opcjonalna funkcja do nawigacji
}

const NotificationsBell: React.FC<NotificationsBellProps> = ({
                                                                 token,
                                                                 username,
                                                                 notificationApiUrl,
                                                                 onNotificationItemClick,
                                                             }) => {
    const [allNotifications, setAllNotifications] = useState<
        INotificationRecord[]
    >([]);
    const [unreadCount, setUnreadCount] = useState(0);
    const [showPanel, setShowPanel] = useState(false);
    const bellRef = useRef<HTMLDivElement>(null); // Ref do obsługi kliknięcia poza dzwonkiem

    const fetchNotifications = async () => {
        if (!notificationApiUrl || !token || !username) return;
        try {
            const res = await fetch(`${notificationApiUrl}/history`, {
                // Backend /history powinien filtrować po userId z tokenu,
                // ale dla pewności możemy też przekazać username, jeśli API tego wymaga.
                // W Twoim NotificationController /history używa jwt.getSubject(),
                // więc musimy upewnić się, że NotificationRecord.userId to nick.
                // Jeśli NotificationRecord.userId to sub, to frontend nie musi wysyłać username.
                // Na razie zakładam, że /history zwraca wszystkie powiadomienia dla użytkownika z tokenu.
                headers: { Authorization: `Bearer ${token}` },
            });
            if (res.ok) {
                const data: INotificationRecord[] = await res.json();
                data.sort((a, b) => b.timestamp - a.timestamp); // Najnowsze na górze
                setAllNotifications(data);
                // Liczymy nieprzeczytane dla zalogowanego użytkownika
                const count = data.filter(
                    (n) => n.userId === username && !n.readNotification,
                ).length;
                setUnreadCount(count);
            } else {
                console.error(
                    "Error fetching notifications:",
                    await res.text(),
                );
            }
        } catch (error) {
            console.error("Error fetching notifications:", error);
        }
    };

    useEffect(() => {
        fetchNotifications();
        const intervalId = setInterval(fetchNotifications, 30000); // Pobieraj co 30 sekund
        return () => clearInterval(intervalId);
    }, [token, notificationApiUrl, username]); // Dodaj username do zależności

    // Zamykanie panelu po kliknięciu poza nim
    useEffect(() => {
        const handleClickOutside = (event: MouseEvent) => {
            if (
                bellRef.current &&
                !bellRef.current.contains(event.target as Node)
            ) {
                setShowPanel(false);
            }
        };
        document.addEventListener('mousedown', handleClickOutside);
        return () => {
            document.removeEventListener('mousedown', handleClickOutside);
        };
    }, [bellRef]);

    const handleMarkAsRead = async (notificationId: string) => {
        if (!notificationApiUrl || !token) return;
        try {
            const res = await fetch(
                `${notificationApiUrl}/${notificationId}/mark-as-read`,
                {
                    method: 'POST',
                    headers: { Authorization: `Bearer ${token}` },
                },
            );
            if (res.ok) {
                console.log(`Notification ${notificationId} marked as read`);
                // Odśwież listę i licznik
                fetchNotifications(); // Najprostszy sposób na odświeżenie
            } else {
                console.error(
                    "Error marking notification as read:",
                    await res.text(),
                );
            }
        } catch (error) {
            console.error("Error marking notification as read:", error);
        }
    };

    const handlePanelNotificationClick = (record: INotificationRecord) => {
        console.log('Notification clicked:', record);
        if (onNotificationItemClick) {
            onNotificationItemClick(record);
        }
        // Możesz tu dodać logikę nawigacji, np. jeśli record.relatedEntityId istnieje
        // np. jeśli masz funkcję navigateToMessage(record.relatedEntityId)
        setShowPanel(false); // Zamknij panel po kliknięciu
    };

    return (
        <div className="notifications-bell-container" ref={bellRef}>
            <button
                onClick={() => setShowPanel(!showPanel)}
                className="bell-button"
                aria-label="Notifications"
            >
                <FiBell size={24} />
                {unreadCount > 0 && (
                    <span className="unread-badge">{unreadCount}</span>
                )}
            </button>
            {showPanel && (
                <NotificationsPanel
                    notifications={allNotifications}
                    onMarkAsRead={handleMarkAsRead}
                    onNotificationClick={handlePanelNotificationClick}
                    currentUsername={username} // Przekaż nick zalogowanego użytkownika
                />
            )}
        </div>
    );
};

export default NotificationsBell;
