// chat-lambda-handlers/src/main/java/pl/projektchmury/chatapp/dao/MessageDao.java
package pl.projektchmury.chatapp.dao;

import pl.projektchmury.chatapp.db.DatabaseManager;
import pl.projektchmury.chatapp.model.Message;

import java.sql.*;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

public class MessageDao {

    public Message saveMessage(Message message) throws SQLException {

        String sql = "INSERT INTO message (author_username, recipient_username, content, file_id, read, created_at) VALUES (?, ?, ?, ?, ?, ?) RETURNING id, created_at";
        try (Connection conn = DatabaseManager.getConnection();
             PreparedStatement pstmt = conn.prepareStatement(sql)) {

            pstmt.setString(1, message.getAuthorUsername());
            pstmt.setString(2, message.getRecipientUsername());
            pstmt.setString(3, message.getContent());
            pstmt.setString(4, message.getFileId());
            pstmt.setBoolean(5, message.isRead());
            message.setCreatedAt(LocalDateTime.now()); // Ustawiamy czas utworzenia
            pstmt.setTimestamp(6, Timestamp.valueOf(message.getCreatedAt()));

            ResultSet rs = pstmt.executeQuery();
            if (rs.next()) {
                message.setId(rs.getLong("id"));
            }
            return message;
        }
    }

    public List<Message> findByAuthorUsername(String username) throws SQLException {
        List<Message> messages = new ArrayList<>();
        String sql = "SELECT id, author_username, recipient_username, content, file_id, read, created_at FROM message WHERE author_username = ? ORDER BY created_at DESC";
        try (Connection conn = DatabaseManager.getConnection();
             PreparedStatement pstmt = conn.prepareStatement(sql)) {
            pstmt.setString(1, username);
            ResultSet rs = pstmt.executeQuery();
            while (rs.next()) {
                messages.add(mapRowToMessage(rs));
            }
        }
        return messages;
    }

    public List<Message> findByRecipientUsername(String username) throws SQLException {
        List<Message> messages = new ArrayList<>();
        String sql = "SELECT id, author_username, recipient_username, content, file_id, read, created_at FROM message WHERE recipient_username = ? ORDER BY created_at DESC";
        try (Connection conn = DatabaseManager.getConnection();
             PreparedStatement pstmt = conn.prepareStatement(sql)) {
            pstmt.setString(1, username);
            ResultSet rs = pstmt.executeQuery();
            while (rs.next()) {
                messages.add(mapRowToMessage(rs));
            }
        }
        return messages;
    }

    public boolean markMessageAsRead(Long messageId, String recipientUsername) throws SQLException {
        String sql = "UPDATE message SET read = TRUE WHERE id = ? AND recipient_username = ? AND read = FALSE";
        try (Connection conn = DatabaseManager.getConnection();
             PreparedStatement pstmt = conn.prepareStatement(sql)) {
            pstmt.setLong(1, messageId);
            pstmt.setString(2, recipientUsername);
            int affectedRows = pstmt.executeUpdate();
            return affectedRows > 0;
        }
    }

    public Message findById(Long messageId) throws SQLException {
        String sql = "SELECT id, author_username, recipient_username, content, file_id, read, created_at FROM message WHERE id = ?";
        try (Connection conn = DatabaseManager.getConnection();
             PreparedStatement pstmt = conn.prepareStatement(sql)) {
            pstmt.setLong(1, messageId);
            ResultSet rs = pstmt.executeQuery();
            if (rs.next()) {
                return mapRowToMessage(rs);
            }
        }
        return null;
    }


    private Message mapRowToMessage(ResultSet rs) throws SQLException {
        Message msg = new Message();
        msg.setId(rs.getLong("id"));
        msg.setAuthorUsername(rs.getString("author_username"));
        msg.setRecipientUsername(rs.getString("recipient_username"));
        msg.setContent(rs.getString("content"));
        msg.setFileId(rs.getString("file_id"));
        msg.setRead(rs.getBoolean("read"));
        Timestamp createdAtTimestamp = rs.getTimestamp("created_at");
        if (createdAtTimestamp != null) {
            msg.setCreatedAt(createdAtTimestamp.toLocalDateTime());
        }
        return msg;
    }
}