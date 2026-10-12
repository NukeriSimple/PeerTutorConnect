<%@ page isErrorPage="true" contentType="text/html;charset=UTF-8" %>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Something went wrong | PeerTutorConnect</title>
    <link rel="stylesheet" href="${pageContext.request.contextPath}/css/style.css">
</head>
<body>
    <main style="max-width:560px;margin:80px auto;text-align:center;font-family:sans-serif;">
        <h1>Oops, something went wrong</h1>
        <p>The page you asked for is unavailable or an unexpected error occurred.</p>
        <p><a href="${pageContext.request.contextPath}/index.jsp">Back to the home page</a></p>
    </main>
</body>
</html>