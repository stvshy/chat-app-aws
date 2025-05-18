// frontend/src/components/NotificationsBell.tsx
import React, { useState, useEffect, useRef } from 'react';
import { FiBell } from 'react-icons/fi';
import NotificationsPanel from './NotificationsPanel';
import { INotificationRecord } from '../types/types.tsx'; // Upewnij się, że ścieżka jest poprawna
import './notifications.css';

interface NotificationsBellProps {
    token: string;
    username: string;
    notificationApiUrl: string;
    onNotificationItemClick: (record: INotificationRecord) => void;
    // Nowe propsy do zarządzania stanem z App.tsx
    notificationsFromApp: INotificationRecord[];
    onNotificationsFetched: (notifications: INotificationRecord[]) => void; // Callback do App.tsx
    onMarkNotificationAsRead: (notificationId: string) => Promise<boolean>; // Funkcja z App.tsx
}

const NotificationsBell: React.FC<NotificationsBellProps> = ({
                                                                 token,
                                                                 username,
                                                                 notificationApiUrl,
                                                                 onNotificationItemClick,
                                                                 notificationsFromApp,
                                                                 onNotificationsFetched,
                                                                 onMarkNotificationAsRead,
                                                             }) => {
    // const [allNotifications, setAllNotifications] = useState<INotificationRecord[]>([]); // Stan zarządzany przez App.tsx
    const [unreadCount, setUnreadCount] = useState(0);
    const [showPanel, setShowPanel] = useState(false);
    const bellRef = useRef<HTMLDivElement>(null);

    const fetchNotifications = async () => {
        if (!notificationApiUrl || !token || !username) return;
        try {
            const res = await fetch(`${notificationApiUrl}/history`, {
                headers: { Authorization: `Bearer ${token}` },
            });
            if (res.ok) {
                const data: INotificationRecord[] = await res.json();
                data.sort((a, b) => b.timestamp - a.timestamp);
                onNotificationsFetched(data); // Aktualizuj stan w App.tsx
            } else {
                console.error("Error fetching notifications:", await res.text());
                onNotificationsFetched([]); // W przypadku błędu, wyślij pustą listę
            }
        } catch (error) {
            console.error("Error fetching notifications:", error);
            onNotificationsFetched([]); // W przypadku błędu, wyślij pustą listę
        }
    };

    useEffect(() => {
        fetchNotifications(); // Pobierz przy montowaniu
        const intervalId = setInterval(fetchNotifications, 30000);
        return () => clearInterval(intervalId);
    }, [token, notificationApiUrl, username]); // Zależności dla pobierania

    // Aktualizuj licznik nieprzeczytanych, gdy zmieni się lista z App.tsx
    useEffect(() => {
        const count = notificationsFromApp.filter(
            (n) => n.userId === username && !n.readNotification,
        ).length;
        setUnreadCount(count);
    }, [notificationsFromApp, username]);


    useEffect(() => {
        const handleClickOutside = (event: MouseEvent) => {
            if (bellRef.current && !bellRef.current.contains(event.target as Node)) {
                setShowPanel(false);
            }
        };
        document.addEventListener('mousedown', handleClickOutside);
        return () => document.removeEventListener('mousedown', handleClickOutside);
    }, [bellRef]);

    // const handleMarkAsReadAndNotifyApp = async (notificationId: string) => {
    //     const success = await onMarkNotificationAsRead(notificationId); // Wywołaj funkcję z App.tsx
    //     if (success) {
    //         // fetchNotifications(); // Nie trzeba, bo App.tsx zaktualizuje notificationsFromApp
    //     }
    // };

    // const handlePanelNotificationClick = (record: INotificationRecord) => {
    //     if (!record.readNotification) {
    //         handleMarkAsReadAndNotifyApp(record.notificationId);
    //     }
    //     onNotificationItemClick(record);
    //     // setShowPanel(false); // Można zostawić lub usunąć, w zależności od preferencji UX
    // };
    const handleMarkNotificationAsReadClickedInPanel = async (notificationId: string) => {
        await onMarkNotificationAsRead(notificationId); // Wywołaj funkcję z App.tsx
        // Stan allNotifications w App.tsx zostanie zaktualizowany, co przefiltruje się tutaj
    };

    // Ta funkcja będzie przekazana do NotificationsPanel jako onNotificationClick
    const handleNotificationContentClickedInPanel = (record: INotificationRecord) => {
        onNotificationItemClick(record); // Wywołaj funkcję z App.tsx
        // App.tsx zajmie się oznaczeniem powiadomienia, wiadomości i podświetleniem
        // setShowPanel(false); // Opcjonalnie zamknij panel
    };
    return (
        <div className="notifications-bell-container" ref={bellRef}>
            <button onClick={() => setShowPanel(!showPanel)} className="bell-button" aria-label="Notifications">
                <FiBell size={24} />
                {unreadCount > 0 && <span className="unread-badge">{unreadCount}</span>}
            </button>
            {showPanel && (
                <NotificationsPanel
                    notifications={notificationsFromApp}
                    onMarkAsRead={handleMarkNotificationAsReadClickedInPanel} // Przekaż tę funkcję
                    onNotificationClick={handleNotificationContentClickedInPanel} // Przekaż tę funkcję
                    currentUsername={username}
                />
            )}
        </div>
    );
};

export default NotificationsBell;
