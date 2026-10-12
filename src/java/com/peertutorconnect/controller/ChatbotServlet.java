package com.peertutorconnect.controller;

import java.io.BufferedReader;
import java.io.IOException;
import java.util.ArrayList;
import java.util.List;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.json.JSONObject;

/**
 * Free, rule-based assistant. No external API, no key, no cost.
 * Each rule has keywords and an answer; the rule with the most keyword hits wins.
 */
@WebServlet(name = "ChatbotServlet", urlPatterns = {"/chatbot"})
public class ChatbotServlet extends HttpServlet {

    private static class Rule {
        final String[] keywords;
        final String answer;
        Rule(String answer, String... keywords) {
            this.keywords = keywords;
            this.answer = answer;
        }
    }

    private static final List<Rule> RULES = new ArrayList<>();
    static {
        RULES.add(new Rule(
            "Hello! I can help with registering, finding and booking tutors, payments, session links, ratings and reports. What would you like to know?",
            "hello", "hi", "hey", "good morning", "good afternoon", "help"));

        RULES.add(new Rule(
            "Click Register, choose Student or Tutor, and fill in your details. We'll email you a confirmation link, and you must confirm your email before you can log in.",
            "register", "sign up", "signup", "create account", "join", "new account"));

        RULES.add(new Rule(
            "If your confirmation email didn't arrive, check your spam folder first. The link only works once you've registered with a valid email address.",
            "confirm", "verification", "verify email", "confirmation email", "didn't get email", "no email"));

        RULES.add(new Rule(
            "Use the Forgot Password link on the login page. Enter your email and we'll send you a link to set a new password.",
            "forgot", "reset password", "lost password", "change password", "can't log in", "cant login", "password"));

        RULES.add(new Rule(
            "Log in as a student and open Find Tutors. You can search for tutors, open a profile to see their subjects, rating and reviews, then choose a time slot to book.",
            "find tutor", "search", "look for tutor", "find a tutor", "browse", "tutors"));

        RULES.add(new Rule(
            "Open a tutor's profile and pick one of their available slots, then submit the booking. The tutor will accept or decline it, and you'll get a notification either way.",
            "book", "booking", "schedule", "reserve", "appointment", "slot"));

        RULES.add(new Rule(
            "After booking, upload your proof of payment so the tutor knows the session is paid for. You'll find the option on your My Sessions page.",
            "pay", "payment", "proof", "paid", "price", "cost", "fee"));

        RULES.add(new Rule(
            "Once the tutor accepts your booking, they add a session link. You'll find it under My Sessions, and you'll also get a notification and a reminder before it starts.",
            "link", "meeting", "zoom", "teams", "join session", "online session", "where is my session"));

        RULES.add(new Rule(
            "Check My Sessions to see the status of each booking. Pending requests that aren't answered in time expire automatically, so you can book another tutor.",
            "my sessions", "status", "pending", "cancel", "expired", "reschedule"));

        RULES.add(new Rule(
            "After a session is completed, you can rate your tutor from 1 to 5 stars and leave a comment. Ratings feed into the tutor's average shown on their profile.",
            "rate", "rating", "review", "stars", "feedback", "comment"));

        RULES.add(new Rule(
            "To become a tutor, register as a Tutor and complete the tutor application with your supporting documents. An admin reviews it, and once approved you can set your availability and accept sessions.",
            "become a tutor", "tutor application", "apply", "be a tutor", "teach", "tutor account", "approved", "approval"));

        RULES.add(new Rule(
            "Approved tutors open Manage Availability and add the dates and times they're free. Students can only book those slots.",
            "availability", "available", "free time", "set my times", "my hours"));

        RULES.add(new Rule(
            "If a tutor thinks a review is unfair, they can report it with a reason. An admin then keeps or removes it, and if removed, the tutor's average rating is recalculated.",
            "report review", "unfair", "flag", "remove review", "reported"));

        RULES.add(new Rule(
            "If someone doesn't attend a booked session, it can be reported as a no-show. An admin reviews it and may issue a strike, so repeated no-shows have consequences.",
            "no show", "no-show", "noshow", "didn't show", "strike", "absent", "missed"));

        RULES.add(new Rule(
            "The bell icon at the top shows your notifications, such as booking updates and reminders. Click 'See all notifications' for the full list.",
            "notification", "notifications", "bell", "alert", "reminder"));

        RULES.add(new Rule(
            "Open your profile from the avatar at the top right. There you can update your details and change your email.",
            "profile", "update details", "change email", "edit account", "my account", "avatar"));

        RULES.add(new Rule(
            "Use the Log out link in the top bar or at the bottom of the sidebar.",
            "log out", "logout", "sign out"));

        RULES.add(new Rule(
            "PeerTutorConnect connects students with verified peer tutors. Students find and book tutors, tutors manage their sessions and availability, and admins keep the platform fair.",
            "what is", "about", "how does it work", "how it works", "purpose", "platform", "peertutorconnect"));

        RULES.add(new Rule(
            "You're welcome! Let me know if there's anything else about PeerTutorConnect I can help with.",
            "thanks", "thank you", "thx", "cheers"));

        RULES.add(new Rule(
            "Goodbye! Good luck with your studies.",
            "bye", "goodbye", "see you"));
    }

    private static final String FALLBACK =
        "I'm not sure about that one. I can help with registering, finding and booking tutors, "
        + "payment proof, session links, ratings, becoming a tutor, and no-show or review reports. "
        + "Try asking about one of those.";

    static String answerFor(String message) {
        String text = " " + message.toLowerCase().replaceAll("[^a-z0-9' -]", " ") + " ";
        Rule best = null;
        int bestScore = 0;
        for (Rule r : RULES) {
            int score = 0;
            for (String k : r.keywords) {
                // short words must match as whole words so "hi" doesn't match "this"
                if (k.length() <= 3) {
                    if (text.contains(" " + k + " ")) score += 2;
                } else if (text.contains(k)) {
                    score += 3;
                }
            }
            if (score > bestScore) {
                bestScore = score;
                best = r;
            }
        }
        return best == null ? FALLBACK : best.answer;
    }

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {

        response.setContentType("application/json;charset=UTF-8");

        StringBuilder bodyBuilder = new StringBuilder();
        try (BufferedReader reader = request.getReader()) {
            String line;
            while ((line = reader.readLine()) != null) {
                bodyBuilder.append(line);
            }
        }

        String userMessage;
        try {
            userMessage = new JSONObject(bodyBuilder.toString()).getString("message");
        } catch (Exception e) {
            response.setStatus(HttpServletResponse.SC_BAD_REQUEST);
            response.getWriter().write("{\"error\":\"Invalid request.\"}");
            return;
        }

        if (userMessage == null || userMessage.trim().isEmpty()) {
            response.setStatus(HttpServletResponse.SC_BAD_REQUEST);
            response.getWriter().write("{\"error\":\"Empty message.\"}");
            return;
        }

        JSONObject outgoing = new JSONObject();
        outgoing.put("reply", answerFor(userMessage));
        response.getWriter().write(outgoing.toString());
    }
}