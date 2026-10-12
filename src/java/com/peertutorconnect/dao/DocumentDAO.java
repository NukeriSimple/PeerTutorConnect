package com.peertutorconnect.dao;

import com.peertutorconnect.util.DBConnection;
import java.sql.*;
import java.util.ArrayList;
import java.util.List;

public class DocumentDAO {

    public static class Document {
        public int documentId;
        public int tutorId;
        public String documentType;
        public String fileUrl;
        public String verificationStatus;
        public String uploadedAt;
    }

    public void saveDocument(int tutorId, String documentType, String fileUrl) throws SQLException {
        String sql = "INSERT INTO supporting_document (tutorId, documentType, fileUrl) VALUES (?, ?, ?)";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, tutorId);
            ps.setString(2, documentType);
            ps.setString(3, fileUrl);
            ps.executeUpdate();
        }
    }

    public List<Document> getDocumentsForTutor(int tutorId) throws SQLException {
        String sql = "SELECT documentId, tutorId, documentType, fileUrl, verificationStatus, uploadedAt " +
                     "FROM supporting_document WHERE tutorId = ? ORDER BY uploadedAt";
        List<Document> list = new ArrayList<>();
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, tutorId);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    list.add(mapRow(rs));
                }
            }
        }
        return list;
    }

    public Document getById(int documentId) throws SQLException {
        String sql = "SELECT documentId, tutorId, documentType, fileUrl, verificationStatus, uploadedAt FROM supporting_document WHERE documentId = ?";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, documentId);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() ? mapRow(rs) : null;
            }
        }
    }

    private Document mapRow(ResultSet rs) throws SQLException {
        Document d = new Document();
        d.documentId = rs.getInt("documentId");
        d.tutorId = rs.getInt("tutorId");
        d.documentType = rs.getString("documentType");
        d.fileUrl = rs.getString("fileUrl");
        d.verificationStatus = rs.getString("verificationStatus");
        d.uploadedAt = rs.getString("uploadedAt");
        return d;
    }

    public Integer getUserIdForTutor(int tutorId) throws SQLException {
        String sql = "SELECT userId FROM tutor WHERE tutorId = ?";
        try (Connection conn = DBConnection.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, tutorId);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() ? rs.getInt("userId") : null;
            }
        }
    }
}