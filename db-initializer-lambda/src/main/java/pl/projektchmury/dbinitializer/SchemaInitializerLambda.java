package pl.projektchmury.dbinitializer;

import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;

import java.sql.Connection;
import java.sql.SQLException;
import java.sql.Statement;

// ZMIANA JEST TUTAJ: implements RequestHandler<Object, String>
public class SchemaInitializerLambda implements RequestHandler<Object, String> {

    @Override
    // ORAZ TUTAJ: public String handleRequest(Object input, Context context)
    public String handleRequest(Object input, Context context) {
        context.getLogger().log("Starting database schema initialization...");

        String createTableSql = "CREATE TABLE IF NOT EXISTS message ("
                + "id BIGSERIAL PRIMARY KEY,"
                + "author_username VARCHAR(255),"
                + "recipient_username VARCHAR(255),"
                + "content TEXT,"
                + "file_id VARCHAR(255),"
                + "read BOOLEAN DEFAULT FALSE NOT NULL,"
                + "created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP"
                + ");";

        try (Connection conn = DatabaseManager.getConnection();
             Statement stmt = conn.createStatement()) {

            context.getLogger().log("Executing CREATE TABLE statement...");
            stmt.execute(createTableSql);
            context.getLogger().log("Table 'message' created successfully or already exists.");

            return "SUCCESS: Database schema initialized successfully.";

        } catch (SQLException e) {
            context.getLogger().log("ERROR: Database initialization failed: " + e.getMessage());
            // Rzucamy RuntimeException, aby Lambda zakończyła się błędem, co jest widoczne w AWS
            throw new RuntimeException("Failed to initialize database schema", e);
        }
    }
}