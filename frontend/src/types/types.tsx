export interface INotificationRecord {
    notificationId: string;
    userId: string;
    type: string;
    message: string;
    timestamp: number;
    status: string;
    readNotification: boolean;
    relatedEntityId?: string;
}

export interface IMessage {
    id: number;
    authorUsername: string;
    recipientUsername: string | null;
    content: string;
    fileId?: string | null;
    read: boolean;
}
