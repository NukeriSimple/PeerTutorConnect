package com.peertutorconnect.util;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;

public class DBConnection {

    private static final String URL = AppConfig.get("db.url",
            "jdbc:mysql://localhost:3306/peertutorconnect?useSSL=false&serverTimezone=UTC&allowPublicKeyRetrieval=true");
    private static final String USER = AppConfig.get("db.user", "ptc_app");
    private static final String PASSWORD = AppConfig.get("db.password", "");

    public static Connection getConnection() throws SQLException {
        try {
            Class.forName("com.mysql.cj.jdbc.Driver");
        } catch (ClassNotFoundException e) {
            throw new SQLException("MySQL JDBC Driver not found on classpath.", e);
        }
        return DriverManager.getConnection(URL, USER, PASSWORD);
    }
}