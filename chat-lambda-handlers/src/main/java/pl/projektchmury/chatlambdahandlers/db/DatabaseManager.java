// chat-lambda-handlers/src/main/java/pl/projektchmury/chatapp/db/DatabaseManager.java
package pl.projektchmury.chatapp.db;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;

public class DatabaseManager {
    private static final String DB_URL = System.getenv("DB_URL"); // np. jdbc:postgresql://host:port/dbname
    private static final String DB_USER = System.getenv("DB_USER");
    private static final String DB_PASSWORD = System.getenv("DB_PASSWORD");

    static {
        try {
            // Załaduj sterownik JDBC PostgreSQL
            Class.forName("org.postgresql.Driver");
        } catch (ClassNotFoundException e) {
            // Logowanie błędu powinno być bardziej zaawansowane w produkcji
            System.err.println("PostgreSQL JDBC Driver not found.");
            e.printStackTrace();
        }
    }

    public static Connection getConnection() throws SQLException {
        if (DB_URL == null || DB_USER == null || DB_PASSWORD == null) {
            throw new SQLException("Database connection parameters (DB_URL, DB_USER, DB_PASSWORD) not set in environment variables.");
        }
        return DriverManager.getConnection(DB_URL, DB_USER, DB_PASSWORD);
    }
}