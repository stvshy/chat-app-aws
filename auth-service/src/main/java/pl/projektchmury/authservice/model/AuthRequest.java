package pl.projektchmury.authservice.model;

// Możesz użyć Lombok, jeśli dodałeś zależność
// import lombok.Data;
// @Data
public class AuthRequest {
    private String username;
    private String password;

    // Gettery i settery, jeśli nie używasz Lombok
    public String getUsername() {
        return username;
    }

    public void setUsername(String username) {
        this.username = username;
    }

    public String getPassword() {
        return password;
    }

    public void setPassword(String password) {
        this.password = password;
    }
}
