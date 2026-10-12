import com.peertutorconnect.util.EscapeUtil;
import com.peertutorconnect.util.PasswordUtil;
import java.security.MessageDigest;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class UtilTests {

    @Test
    void hashIsSaltedSoSamePasswordGivesDifferentHashes() {
        assertNotEquals(PasswordUtil.hash("secret123"), PasswordUtil.hash("secret123"));
    }

    @Test
    void verifyAcceptsCorrectAndRejectsWrongPassword() {
        String h = PasswordUtil.hash("secret123");
        assertTrue(PasswordUtil.verify("secret123", h));
        assertFalse(PasswordUtil.verify("wrong", h));
    }

    @Test
    void verifyHandlesNullsAndGarbage() {
        assertFalse(PasswordUtil.verify(null, "x"));
        assertFalse(PasswordUtil.verify("a", null));
        assertFalse(PasswordUtil.verify("a", "pbkdf2$not$valid"));
    }

    @Test
    void legacySha256HashesStillWorkAndAreFlaggedForUpgrade() throws Exception {
        byte[] d = MessageDigest.getInstance("SHA-256").digest("oldpass".getBytes("UTF-8"));
        StringBuilder sb = new StringBuilder();
        for (byte b : d) sb.append(String.format("%02x", b));
        String legacy = sb.toString();

        assertTrue(PasswordUtil.verify("oldpass", legacy));
        assertFalse(PasswordUtil.verify("nope", legacy));
        assertTrue(PasswordUtil.needsRehash(legacy));
        assertFalse(PasswordUtil.needsRehash(PasswordUtil.hash("x")));
    }

    @Test
    void escapeNeutralisesHtml() {
        assertEquals("&lt;script&gt;alert(&#39;x&#39;)&lt;/script&gt;", EscapeUtil.html("<script>alert('x')</script>"));
        assertEquals("", EscapeUtil.html(null));
        assertEquals("a &amp; b", EscapeUtil.html("a & b"));
    }
}