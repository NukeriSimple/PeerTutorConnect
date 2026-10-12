# PeerTutorConnect

A Java web application (JSP + Servlets, Apache Tomcat 10.1, MySQL) that connects students with peer tutors:
registration, tutor verification, availability, bookings, sessions, ratings/reviews, no-show strikes,
tutor subscriptions, notifications, an admin dashboard and a chatbot.

## Tech stack
- Java, Jakarta Servlet/JSP (Tomcat 10.1), NetBeans Ant project
- MySQL 8 (mysql-connector-j 8.0.33)
- Jakarta Mail (angus-mail 2.0.4), org.json

## Setup
1. Create the database and import `database/schema.sql`.
2. Copy `src/java/config.properties.example` to `src/java/config.properties` and fill in your DB/SMTP details (this file is git-ignored).
3. Add the required jars to `web/WEB-INF/lib` (or your project libraries): mysql-connector-j-8.0.33, angus-mail-2.0.4, angus-activation-2.0.2, jakarta.mail-api-2.1.3, jakarta.activation-api-2.1.3, json-20250107.
4. Open in NetBeans, build, and deploy to Tomcat 10.1 at `/PeerTutorConnect`.

## Project structure
```
PeerTutorConnect/
├── build.xml
├── database/                  # schema.sql (export from MySQL)
├── nbproject/                 # NetBeans project config
├── src/
│   ├── conf/MANIFEST.MF
│   └── java/
│       ├── config.properties.example
│       └── com/peertutorconnect/
│           ├── controller/    # 23 servlets (Login, Register, Booking, Subscription, NoShow, Chatbot, ...)
│           ├── dao/           # 14 data-access classes (UserDAO, BookingDAO, TutorDAO, ...)
│           ├── filter/        # AuthFilter
│           ├── listener/      # MaintenanceListener
│           └── util/          # AppConfig, DBConnection, EmailUtil, PasswordUtil, ...
├── test/UtilTests.java
└── web/
    ├── META-INF/context.xml
    ├── WEB-INF/web.xml
    ├── css/style.css
    ├── includes/              # header, footer, sidebar, toast, modals, chatbot widget
    └── *.jsp                  # student, tutor and admin pages
```
