package com.peertutorconnect.util;

import jakarta.mail.Message;
import jakarta.mail.MessagingException;
import jakarta.mail.PasswordAuthentication;
import jakarta.mail.Session;
import jakarta.mail.Transport;
import jakarta.mail.internet.InternetAddress;
import jakarta.mail.internet.MimeMessage;
import java.util.Properties;
import java.util.logging.Level;
import java.util.logging.Logger;

public class EmailUtil {

    private static final Logger LOGGER = Logger.getLogger(EmailUtil.class.getName());

    // Credentials come from config.properties / environment variables (see AppConfig).
    private static final String SMTP_USERNAME = AppConfig.get("smtp.username", "");
    private static final String SMTP_APP_PASSWORD = AppConfig.get("smtp.password", "");

    private static Session getSession() {
        Properties props = new Properties();
        props.put("mail.smtp.auth", "true");
        props.put("mail.smtp.starttls.enable", "true");
        props.put("mail.smtp.host", "smtp.gmail.com");
        props.put("mail.smtp.port", "587");

        return Session.getInstance(props, new jakarta.mail.Authenticator() {
            @Override
            protected PasswordAuthentication getPasswordAuthentication() {
                return new PasswordAuthentication(SMTP_USERNAME, SMTP_APP_PASSWORD);
            }
        });
    }

    public static void sendWelcomeEmail(String toEmail, String name, String role) {
        try {
            Session session = getSession();

            Message message = new MimeMessage(session);
            message.setFrom(new InternetAddress(SMTP_USERNAME, "PeerTutorConnect"));
            message.setRecipients(Message.RecipientType.TO, InternetAddress.parse(toEmail));
            message.setSubject("Welcome to PeerTutorConnect!");

            String roleMessage = "STUDENT".equalsIgnoreCase(role)
                    ? "you can log in and start finding tutors"
                    : "you can log in and start offering your own tutoring sessions";

            String body = "Hi " + name + ",\n\n"
                    + "Your PeerTutorConnect account has been created successfully - "
                    + roleMessage + ".\n\n"
                    + "Thank you for registering!\n\n"
                    + "- The PeerTutorConnect Team";

            message.setText(body);

            Transport.send(message);
            LOGGER.log(Level.INFO, "Welcome email sent to {0}", toEmail);

        } catch (MessagingException | java.io.UnsupportedEncodingException e) {
            // Deliberately not rethrown: a failed email should never block registration
            LOGGER.log(Level.WARNING, "Failed to send welcome email to " + toEmail, e);
        }
    }

    public static void sendPasswordResetEmail(String toEmail, String name, String resetLink) {
        try {
            Session session = getSession();

            Message message = new MimeMessage(session);
            message.setFrom(new InternetAddress(SMTP_USERNAME, "PeerTutorConnect"));
            message.setRecipients(Message.RecipientType.TO, InternetAddress.parse(toEmail));
            message.setSubject("Reset your PeerTutorConnect password");

            String body = "Hi " + name + ",\n\n"
                    + "We received a request to reset your PeerTutorConnect password. "
                    + "Click the link below to set a new one. This link expires in 1 hour.\n\n"
                    + resetLink + "\n\n"
                    + "If you didn't request this, you can safely ignore this email - "
                    + "your password won't be changed.\n\n"
                    + "- The PeerTutorConnect Team";

            message.setText(body);

            Transport.send(message);
            LOGGER.log(Level.INFO, "Password reset email sent to {0}", toEmail);

        } catch (MessagingException | java.io.UnsupportedEncodingException e) {
            LOGGER.log(Level.WARNING, "Failed to send password reset email to " + toEmail, e);
        }
    }

    /**
     * Sent to the NEW address a user is trying to change their email to. The
     * change only takes effect once they click the confirmation link, which
     * proves they actually control that inbox.
     */
    public static void sendEmailChangeConfirmation(String newEmail, String name, String confirmLink) {
        try {
            Session session = getSession();

            Message message = new MimeMessage(session);
            message.setFrom(new InternetAddress(SMTP_USERNAME, "PeerTutorConnect"));
            message.setRecipients(Message.RecipientType.TO, InternetAddress.parse(newEmail));
            message.setSubject("Confirm your new PeerTutorConnect email");

            String body = "Hi " + name + ",\n\n"
                    + "We received a request to change the email on your PeerTutorConnect "
                    + "account to this address. Click the link below to confirm the change. "
                    + "This link expires in 1 hour.\n\n"
                    + confirmLink + "\n\n"
                    + "If you didn't request this, you can safely ignore this email - "
                    + "your account email won't be changed.\n\n"
                    + "- The PeerTutorConnect Team";

            message.setText(body);

            Transport.send(message);
            LOGGER.log(Level.INFO, "Email change confirmation sent to {0}", newEmail);

        } catch (MessagingException | java.io.UnsupportedEncodingException e) {
            LOGGER.log(Level.WARNING, "Failed to send email change confirmation to " + newEmail, e);
        }
    }

    /**
     * Booking confirmation, sent to both the student and the tutor when a
     * booking is created. isForTutor controls wording only ("with your student"
     * vs "with your tutor") — the schedule details are the same for both
     * recipients.
     */
    public static void sendBookingConfirmationEmail(String toEmail, String toName, String otherPartyName,
            String bookingDate, String startTime, String endTime,
            boolean isForTutor) {
        try {
            Session session = getSession();

            Message message = new MimeMessage(session);
            message.setFrom(new InternetAddress(SMTP_USERNAME, "PeerTutorConnect"));
            message.setRecipients(Message.RecipientType.TO, InternetAddress.parse(toEmail));
            message.setSubject("Your PeerTutorConnect session is booked");

            String otherPartyLabel = isForTutor ? "student" : "tutor";
            String statusNote = isForTutor
                    ? "Please log in to accept or decline this request."
                    : "You'll get a notification once the tutor responds to your request.";

            String body = "Hi " + toName + ",\n\n"
                    + "A tutoring session has been booked with your " + otherPartyLabel + ", "
                    + otherPartyName + ".\n\n"
                    + "Date: " + bookingDate + "\n"
                    + "Time: " + startTime + " - " + endTime + "\n\n"
                    + statusNote + "\n\n"
                    + "- The PeerTutorConnect Team";

            message.setText(body);

            Transport.send(message);
            LOGGER.log(Level.INFO, "Booking confirmation sent to {0}", toEmail);

        } catch (MessagingException | java.io.UnsupportedEncodingException e) {
            // Deliberately not rethrown: a failed email should never block a booking
            LOGGER.log(Level.WARNING, "Failed to send booking confirmation to " + toEmail, e);
        }
    }

    /**
     * Sent right after registration (and when a blocked login asks for a new
     * link).
     */
    public static void sendVerificationEmail(String toEmail, String name, String role, String verifyLink) {
        try {
            Session session = getSession();

            Message message = new MimeMessage(session);
            message.setFrom(new InternetAddress(SMTP_USERNAME, "PeerTutorConnect"));
            message.setRecipients(Message.RecipientType.TO, InternetAddress.parse(toEmail));
            message.setSubject("Confirm your PeerTutorConnect account");

            String roleMessage = "STUDENT".equalsIgnoreCase(role)
                    ? "start finding tutors"
                    : "start offering your own tutoring sessions";

            String body = "Hi " + name + ",\n\n"
                    + "Welcome to PeerTutorConnect! Please confirm your email address to activate "
                    + "your account. Once confirmed, you can log in and " + roleMessage + ".\n\n"
                    + "Confirm my email: " + verifyLink + "\n\n"
                    + "This link expires in 24 hours. If you didn't create this account, "
                    + "you can safely ignore this email.\n\n"
                    + "- The PeerTutorConnect Team";

            message.setText(body);

            Transport.send(message);
            LOGGER.log(Level.INFO, "Verification email sent to {0}", toEmail);

        } catch (MessagingException | java.io.UnsupportedEncodingException e) {
            LOGGER.log(Level.WARNING, "Failed to send verification email to " + toEmail, e);
        }
    }

    /**
     * Plain-text email used for reminders. Failures are logged, never thrown.
     */
    public static void sendSimpleEmail(String toEmail, String subject, String body) {
        if (toEmail == null || toEmail.trim().isEmpty()) {
            return;
        }
        try {
            Session session = getSession();
            Message message = new MimeMessage(session);
            message.setFrom(new InternetAddress(SMTP_USERNAME, "PeerTutorConnect"));
            message.setRecipients(Message.RecipientType.TO, InternetAddress.parse(toEmail));
            message.setSubject(subject);
            message.setText(body);
            Transport.send(message);
        } catch (MessagingException | java.io.UnsupportedEncodingException e) {
            LOGGER.log(Level.WARNING, "Failed to send email to " + toEmail, e);
        }
    }
}
