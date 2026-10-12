<%@ page import="java.util.Properties, jakarta.mail.*, jakarta.mail.internet.*, com.peertutorconnect.util.AppConfig" %>
<%@ page contentType="text/html;charset=UTF-8" %>
<!DOCTYPE html>
<html>
<body>
<h2>Mail test</h2>
<%
    String to = request.getParameter("to");
    if (to == null || to.isEmpty()) {
%>
    <form method="get">
        Send test email to: <input name="to" size="35">
        <button type="submit">Send</button>
    </form>
<%
    } else {
        final String user = AppConfig.get("smtp.username", "nukerisimple@gmail.com");
        final String pass = AppConfig.get("smtp.password", "hndjsecksqdmsbat");
        try {
            Properties props = new Properties();
            props.put("mail.smtp.auth", "true");
            props.put("mail.smtp.starttls.enable", "true");
            props.put("mail.smtp.host", "smtp.gmail.com");
            props.put("mail.smtp.port", "587");
            Session mailSession = Session.getInstance(props, new Authenticator() {
                protected PasswordAuthentication getPasswordAuthentication() {
                    return new PasswordAuthentication(user, pass);
                }
            });
            Message msg = new MimeMessage(mailSession);
            msg.setFrom(new InternetAddress(user, "PeerTutorConnect"));
            msg.setRecipients(Message.RecipientType.TO, InternetAddress.parse(to));
            msg.setSubject("PeerTutorConnect mail test");
            msg.setText("If you can read this, email sending works.");
            Transport.send(msg);
            out.println("<p style='color:green'>SENT using account: " + user + "</p>");
        } catch (Exception e) {
            out.println("<p style='color:red'>FAILED: " + e.getClass().getName() + "<br>" + e.getMessage() + "</p>");
        }
    }
%>
</body>
</html>