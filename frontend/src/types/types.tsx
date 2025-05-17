// frontend/src/types.ts
export interface INotificationRecord {
    notificationId: string;
    userId: string; // Nick użytkownika, dla którego jest powiadomienie
    type: string;   // np. "NEW_MESSAGE", "NEW_MESSAGE_WITH_FILE"
    message: string; // Treść powiadomienia np. "marek sent you a message"
    timestamp: number;
    status: string; // "SENT" lub "FAILED"
    readNotification: boolean; // Czy powiadomienie zostało "kliknięte/zobaczone" w panelu
    relatedEntityId?: string; // ID oryginalnej wiadomości z chat-service
    // Możesz dodać inne pola, które zwraca Twój backend, np. subject
}

// Możesz tu też trzymać interfejs IMessage, jeśli chcesz mieć typy w jednym miejscu
export interface IMessage {
    id: number;
    authorUsername: string;
    recipientUsername: string | null;
    content: string;
    fileId?: string | null;
    read: boolean;
}
