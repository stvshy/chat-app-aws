import React from 'react';
import {FiCheckSquare, FiMessageSquare, FiFileText, FiBell} from 'react-icons/fi'; // Ikony
import { INotificationRecord } from '../types/types.tsx'; // Zaimportuj typ
import './notifications.css'; // Utworzymy ten plik CSS za chwilę

interface NotificationsPanelProps {
    notifications: INotificationRecord[];
    onMarkAsRead: (notificationId: string) => void;
    onNotificationClick: (record: INotificationRecord) => void; // Do obsługi kliknięcia w treść powiadomienia
    currentUsername: string; // Aby filtrować powiadomienia dla zalogowanego użytkownika
}

const NotificationsPanel: React.FC<NotificationsPanelProps> = ({
                                                                   notifications,
                                                                   onMarkAsRead,
                                                                   onNotificationClick,
                                                                   currentUsername,
                                                               }) => {
    // Filtruj powiadomienia tylko dla bieżącego użytkownika
    // Zakładamy, że NotificationRecord.userId to nick użytkownika
    const userNotifications = notifications.filter(
        (n) => n.userId === currentUsername,
    );

    if (!userNotifications.length) {
        return (
            <div className="notifications-panel empty">
                <p>No new notifications.</p>
            </div>
        );
    }

    const getIconForType = (type: string) => {
        if (type.includes('MESSAGE')) {
            return <FiMessageSquare className="notification-type-icon" />;
        }
        if (type.includes('FILE')) {
            return <FiFileText className="notification-type-icon" />;
        }
        return <FiBell className="notification-type-icon" />; // Domyślna ikona
    };

    return (
        <div className="notifications-panel">
            <ul className="notification-list">
                {userNotifications.map((record) => (
                    <li
                        key={record.notificationId}
                        className={`notification-item ${
                            !record.readNotification ? 'unread' : ''
                        }`}
                    >
                        <div
                            className="notification-content-wrapper"
                            onClick={() => onNotificationClick(record)} // Kliknięcie w treść
                        >
                            {getIconForType(record.type)}
                            <div className="notification-text">
                                <p className="notification-message">
                                    {record.message}
                                </p>
                                <small className="notification-timestamp">
                                    {new Date(
                                        record.timestamp,
                                    ).toLocaleString()}
                                </small>
                            </div>
                        </div>
                        {!record.readNotification && (
                            <button
                                className="mark-read-button"
                                onClick={(e) => {
                                    e.stopPropagation(); // Zapobiegaj kliknięciu w cały element li
                                    onMarkAsRead(record.notificationId);
                                }}
                                title="Mark as read"
                            >
                                <FiCheckSquare size={18} />
                            </button>
                        )}
                    </li>
                ))}
            </ul>
        </div>
    );
};

export default NotificationsPanel;
