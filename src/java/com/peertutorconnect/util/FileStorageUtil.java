package com.peertutorconnect.util;

import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;
import java.util.Set;
import java.util.UUID;
import jakarta.servlet.http.Part;

public class FileStorageUtil {

    private static final String UPLOAD_DIR = AppConfig.get("upload.dir",
            System.getProperty("java.io.tmpdir") + java.io.File.separator + "PeerTutorConnectUploads");
    private static final Set<String> ALLOWED_EXTENSIONS = Set.of(".pdf", ".jpg", ".jpeg", ".png");
    private static final long MAX_BYTES = 5L * 1024 * 1024;

    /** Checks size, extension and file signature without saving anything. */
    public static void validate(Part filePart) throws IOException {
        if (filePart == null || filePart.getSize() == 0) {
            return;
        }
        if (filePart.getSize() > MAX_BYTES) {
            throw new IllegalArgumentException("Each file must be 5 MB or smaller.");
        }
        String extension = extensionOf(getFileName(filePart));
        if (!ALLOWED_EXTENSIONS.contains(extension)) {
            throw new IllegalArgumentException("Only PDF, JPG or PNG files are allowed.");
        }
        byte[] head = new byte[4];
        int read;
        try (InputStream in = filePart.getInputStream()) {
            read = in.read(head);
        }
        if (read < 4 || !signatureMatches(extension, head)) {
            throw new IllegalArgumentException("The file content does not match its type. Upload a real PDF, JPG or PNG.");
        }
    }

    public static String saveFile(Part filePart, String prefix) throws IOException {
        if (filePart == null || filePart.getSize() == 0) {
            return null;
        }
        validate(filePart);

        Path uploadPath = Paths.get(UPLOAD_DIR);
        if (!Files.exists(uploadPath)) {
            Files.createDirectories(uploadPath);
        }

        String storedName = prefix + "_" + UUID.randomUUID() + extensionOf(getFileName(filePart));
        Path targetPath = uploadPath.resolve(storedName);

        try (InputStream input = filePart.getInputStream()) {
            Files.copy(input, targetPath, StandardCopyOption.REPLACE_EXISTING);
        }
        return targetPath.toString();
    }

    private static boolean signatureMatches(String ext, byte[] b) {
        switch (ext) {
            case ".pdf":
                return b[0] == '%' && b[1] == 'P' && b[2] == 'D' && b[3] == 'F';
            case ".png":
                return (b[0] & 0xFF) == 0x89 && b[1] == 'P' && b[2] == 'N' && b[3] == 'G';
            default:
                return (b[0] & 0xFF) == 0xFF && (b[1] & 0xFF) == 0xD8 && (b[2] & 0xFF) == 0xFF;
        }
    }

    private static String extensionOf(String name) {
        int dot = name.lastIndexOf('.');
        return dot >= 0 ? name.substring(dot).toLowerCase() : "";
    }

    private static String getFileName(Part part) {
        String header = part.getHeader("content-disposition");
        if (header == null) return "file";
        for (String token : header.split(";")) {
            token = token.trim();
            if (token.startsWith("filename")) {
                String value = token.substring(token.indexOf('=') + 1).trim().replace("\"", "");
                return value.replaceAll(".*[/\\\\]", "");
            }
        }
        return "file";
    }
}