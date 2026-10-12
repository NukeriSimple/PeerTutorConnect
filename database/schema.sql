CREATE DATABASE  IF NOT EXISTS `peertutorconnect` /*!40100 DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci */ /*!80016 DEFAULT ENCRYPTION='N' */;
USE `peertutorconnect`;
-- MySQL dump 10.13  Distrib 8.0.46, for Win64 (x86_64)
--
-- Host: localhost    Database: peertutorconnect
-- ------------------------------------------------------
-- Server version	8.0.46

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `audit_log`
--

DROP TABLE IF EXISTS `audit_log`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `audit_log` (
  `logId` int NOT NULL AUTO_INCREMENT,
  `userId` int DEFAULT NULL,
  `userName` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `action` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `details` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `createdAt` datetime DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`logId`),
  KEY `userId` (`userId`),
  CONSTRAINT `audit_log_ibfk_1` FOREIGN KEY (`userId`) REFERENCES `user` (`userId`) ON DELETE SET NULL
) ENGINE=InnoDB AUTO_INCREMENT=366 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `availability`
--

DROP TABLE IF EXISTS `availability`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `availability` (
  `availabilityId` int NOT NULL AUTO_INCREMENT,
  `tutorId` int NOT NULL,
  `date` date NOT NULL,
  `startTime` time NOT NULL,
  `endTime` time NOT NULL,
  `isBooked` tinyint(1) DEFAULT '0',
  PRIMARY KEY (`availabilityId`),
  KEY `tutorId` (`tutorId`),
  CONSTRAINT `availability_ibfk_1` FOREIGN KEY (`tutorId`) REFERENCES `tutor` (`tutorId`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=48 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `booking`
--

DROP TABLE IF EXISTS `booking`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `booking` (
  `bookingId` int NOT NULL AUTO_INCREMENT,
  `studentId` int NOT NULL,
  `tutorId` int NOT NULL,
  `availabilityId` int NOT NULL,
  `bookingDate` date NOT NULL,
  `startTime` time NOT NULL,
  `endTime` time NOT NULL,
  `status` varchar(30) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'PENDING',
  `declineReason` text COLLATE utf8mb4_unicode_ci,
  `createdAt` datetime DEFAULT CURRENT_TIMESTAMP,
  `emailReminderSent` tinyint(1) NOT NULL DEFAULT '0',
  `smsReminderSent` tinyint(1) NOT NULL DEFAULT '0',
  `cancelReason` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `cancellationFee` decimal(10,2) NOT NULL DEFAULT '0.00',
  `cancelledAt` datetime DEFAULT NULL,
  `description` text COLLATE utf8mb4_unicode_ci,
  `paymentProofUrl` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `paymentSubmittedAt` datetime DEFAULT NULL,
  `refundPaysharp` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`bookingId`),
  KEY `studentId` (`studentId`),
  KEY `tutorId` (`tutorId`),
  KEY `availabilityId` (`availabilityId`),
  CONSTRAINT `booking_ibfk_1` FOREIGN KEY (`studentId`) REFERENCES `student` (`studentId`) ON DELETE CASCADE,
  CONSTRAINT `booking_ibfk_2` FOREIGN KEY (`tutorId`) REFERENCES `tutor` (`tutorId`) ON DELETE CASCADE,
  CONSTRAINT `booking_ibfk_3` FOREIGN KEY (`availabilityId`) REFERENCES `availability` (`availabilityId`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=34 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `booking_slot`
--

DROP TABLE IF EXISTS `booking_slot`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `booking_slot` (
  `bookingSlotId` int NOT NULL AUTO_INCREMENT,
  `bookingId` int NOT NULL,
  `availabilityId` int NOT NULL,
  PRIMARY KEY (`bookingSlotId`),
  UNIQUE KEY `uq_booking_slot` (`bookingId`,`availabilityId`),
  KEY `idx_booking_slot_avail` (`availabilityId`),
  CONSTRAINT `fk_bs_avail` FOREIGN KEY (`availabilityId`) REFERENCES `availability` (`availabilityId`) ON DELETE CASCADE,
  CONSTRAINT `fk_bs_booking` FOREIGN KEY (`bookingId`) REFERENCES `booking` (`bookingId`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=16 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `no_show_report`
--

DROP TABLE IF EXISTS `no_show_report`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `no_show_report` (
  `reportId` int NOT NULL AUTO_INCREMENT,
  `bookingId` int NOT NULL,
  `absentRole` varchar(10) COLLATE utf8mb4_unicode_ci NOT NULL,
  `absentUserId` int NOT NULL,
  `reporterUserId` int NOT NULL,
  `note` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `status` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'PENDING',
  `createdAt` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `resolvedAt` datetime DEFAULT NULL,
  `resolvedBy` int DEFAULT NULL,
  PRIMARY KEY (`reportId`),
  UNIQUE KEY `uq_noshow_booking` (`bookingId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `notification`
--

DROP TABLE IF EXISTS `notification`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `notification` (
  `notificationId` int NOT NULL AUTO_INCREMENT,
  `userId` int NOT NULL,
  `message` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `link` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `isRead` tinyint(1) DEFAULT '0',
  `createdAt` datetime DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`notificationId`),
  KEY `userId` (`userId`),
  CONSTRAINT `notification_ibfk_1` FOREIGN KEY (`userId`) REFERENCES `user` (`userId`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=109 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `rating`
--

DROP TABLE IF EXISTS `rating`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `rating` (
  `ratingId` int NOT NULL AUTO_INCREMENT,
  `sessionId` int NOT NULL,
  `studentId` int NOT NULL,
  `stars` int NOT NULL,
  `comment` text COLLATE utf8mb4_unicode_ci,
  `createdAt` datetime DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`ratingId`),
  KEY `sessionId` (`sessionId`),
  KEY `studentId` (`studentId`),
  CONSTRAINT `rating_ibfk_1` FOREIGN KEY (`sessionId`) REFERENCES `session` (`sessionId`) ON DELETE CASCADE,
  CONSTRAINT `rating_ibfk_2` FOREIGN KEY (`studentId`) REFERENCES `student` (`studentId`) ON DELETE CASCADE,
  CONSTRAINT `rating_chk_1` CHECK ((`stars` between 1 and 5))
) ENGINE=InnoDB AUTO_INCREMENT=14 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `review_flag`
--

DROP TABLE IF EXISTS `review_flag`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `review_flag` (
  `flagId` int NOT NULL AUTO_INCREMENT,
  `ratingId` int NOT NULL,
  `tutorId` int NOT NULL,
  `tutorUserId` int NOT NULL,
  `tutorName` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `studentUserId` int DEFAULT NULL,
  `studentName` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `stars` int DEFAULT NULL,
  `comment` text COLLATE utf8mb4_unicode_ci,
  `reason` varchar(500) COLLATE utf8mb4_unicode_ci NOT NULL,
  `status` varchar(12) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'PENDING',
  `createdAt` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `resolvedAt` timestamp NULL DEFAULT NULL,
  `resolvedBy` int DEFAULT NULL,
  PRIMARY KEY (`flagId`),
  UNIQUE KEY `uq_review_flag_rating` (`ratingId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `session`
--

DROP TABLE IF EXISTS `session`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `session` (
  `sessionId` int NOT NULL AUTO_INCREMENT,
  `bookingId` int NOT NULL,
  `sessionDate` date NOT NULL,
  `startTime` time NOT NULL,
  `endTime` time NOT NULL,
  `meetingLink` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `notes` text COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`sessionId`),
  UNIQUE KEY `bookingId` (`bookingId`),
  CONSTRAINT `session_ibfk_1` FOREIGN KEY (`bookingId`) REFERENCES `booking` (`bookingId`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=26 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `student`
--

DROP TABLE IF EXISTS `student`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `student` (
  `studentId` int NOT NULL AUTO_INCREMENT,
  `userId` int NOT NULL,
  `department` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `yearOfStudy` int NOT NULL,
  PRIMARY KEY (`studentId`),
  KEY `userId` (`userId`),
  CONSTRAINT `student_ibfk_1` FOREIGN KEY (`userId`) REFERENCES `user` (`userId`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=25 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `subject`
--

DROP TABLE IF EXISTS `subject`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `subject` (
  `subjectId` int NOT NULL AUTO_INCREMENT,
  `moduleCode` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL,
  `name` varchar(150) COLLATE utf8mb4_unicode_ci NOT NULL,
  `department` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`subjectId`),
  UNIQUE KEY `moduleCode` (`moduleCode`)
) ENGINE=InnoDB AUTO_INCREMENT=9 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `subscription_payment`
--

DROP TABLE IF EXISTS `subscription_payment`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `subscription_payment` (
  `paymentId` int NOT NULL AUTO_INCREMENT,
  `tutorId` int NOT NULL,
  `tutorUserId` int NOT NULL,
  `tutorName` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `period` varchar(7) COLLATE utf8mb4_unicode_ci NOT NULL,
  `amount` decimal(8,2) NOT NULL,
  `proofPath` varchar(500) COLLATE utf8mb4_unicode_ci NOT NULL,
  `status` varchar(10) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'PENDING',
  `rejectReason` varchar(300) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `submittedAt` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `reviewedAt` timestamp NULL DEFAULT NULL,
  `reviewedBy` int DEFAULT NULL,
  PRIMARY KEY (`paymentId`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `supporting_document`
--

DROP TABLE IF EXISTS `supporting_document`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `supporting_document` (
  `documentId` int NOT NULL AUTO_INCREMENT,
  `tutorId` int NOT NULL,
  `documentType` enum('TRANSCRIPT','STUDENT_ID','PROOF_OF_REG','OTHER') COLLATE utf8mb4_unicode_ci NOT NULL,
  `fileUrl` varchar(500) COLLATE utf8mb4_unicode_ci NOT NULL,
  `uploadedAt` datetime DEFAULT CURRENT_TIMESTAMP,
  `verificationStatus` enum('PENDING','VERIFIED','REJECTED') COLLATE utf8mb4_unicode_ci DEFAULT 'PENDING',
  PRIMARY KEY (`documentId`),
  KEY `tutorId` (`tutorId`),
  CONSTRAINT `supporting_document_ibfk_1` FOREIGN KEY (`tutorId`) REFERENCES `tutor` (`tutorId`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=29 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `tutor`
--

DROP TABLE IF EXISTS `tutor`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `tutor` (
  `tutorId` int NOT NULL AUTO_INCREMENT,
  `userId` int NOT NULL,
  `bio` text COLLATE utf8mb4_unicode_ci,
  `hourlyRate` decimal(8,2) NOT NULL,
  `isVerified` tinyint(1) DEFAULT '0',
  `verifiedAt` datetime DEFAULT NULL,
  `averageRating` decimal(3,2) DEFAULT '0.00',
  `noShowCount` int DEFAULT '0',
  `applicationComplete` tinyint(1) NOT NULL DEFAULT '0',
  `paysharpDetails` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`tutorId`),
  KEY `userId` (`userId`),
  CONSTRAINT `tutor_ibfk_1` FOREIGN KEY (`userId`) REFERENCES `user` (`userId`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=24 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `tutor_fee`
--

DROP TABLE IF EXISTS `tutor_fee`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `tutor_fee` (
  `feeId` int NOT NULL AUTO_INCREMENT,
  `tutorId` int NOT NULL,
  `period` char(7) COLLATE utf8mb4_unicode_ci NOT NULL,
  `amount` decimal(8,2) NOT NULL DEFAULT '59.99',
  `status` varchar(12) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'DUE',
  `proofPath` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `submittedAt` timestamp NULL DEFAULT NULL,
  `reviewedAt` timestamp NULL DEFAULT NULL,
  `reviewedBy` int DEFAULT NULL,
  `rejectReason` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `reminderSent` tinyint(1) NOT NULL DEFAULT '0',
  `flaggedAt` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`feeId`),
  UNIQUE KEY `uq_fee_tutor_period` (`tutorId`,`period`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `tutor_subject`
--

DROP TABLE IF EXISTS `tutor_subject`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `tutor_subject` (
  `tutorId` int NOT NULL,
  `subjectId` int NOT NULL,
  PRIMARY KEY (`tutorId`,`subjectId`),
  KEY `subjectId` (`subjectId`),
  CONSTRAINT `tutor_subject_ibfk_1` FOREIGN KEY (`tutorId`) REFERENCES `tutor` (`tutorId`) ON DELETE CASCADE,
  CONSTRAINT `tutor_subject_ibfk_2` FOREIGN KEY (`subjectId`) REFERENCES `subject` (`subjectId`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `tutor_subscription`
--

DROP TABLE IF EXISTS `tutor_subscription`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `tutor_subscription` (
  `tutorId` int NOT NULL,
  `paidUntil` date NOT NULL,
  `frozen` tinyint(1) NOT NULL DEFAULT '0',
  `frozenAt` timestamp NULL DEFAULT NULL,
  `lastReminder` varchar(7) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`tutorId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `user`
--

DROP TABLE IF EXISTS `user`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `user` (
  `userId` int NOT NULL AUTO_INCREMENT,
  `email` varchar(150) COLLATE utf8mb4_unicode_ci NOT NULL,
  `passwordHash` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `name` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `phone` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `role` enum('STUDENT','TUTOR','ADMIN') COLLATE utf8mb4_unicode_ci NOT NULL,
  `createdAt` datetime DEFAULT CURRENT_TIMESTAMP,
  `resetToken` varchar(64) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `resetTokenExpiry` timestamp NULL DEFAULT NULL,
  `pendingEmail` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `emailChangeToken` varchar(64) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `emailChangeTokenExpiry` datetime DEFAULT NULL,
  `emailVerified` tinyint(1) NOT NULL DEFAULT '0',
  `verifyToken` varchar(64) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `verifyTokenExpiry` datetime DEFAULT NULL,
  `strikes` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`userId`),
  UNIQUE KEY `email` (`email`),
  KEY `idx_user_verifyToken` (`verifyToken`)
) ENGINE=InnoDB AUTO_INCREMENT=48 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2026-10-12 17:05:14
