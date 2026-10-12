package com.peertutorconnect.listener;

import com.peertutorconnect.util.MaintenanceJob;
import jakarta.servlet.ServletContextEvent;
import jakarta.servlet.ServletContextListener;
import jakarta.servlet.annotation.WebListener;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;
import java.util.logging.Level;
import java.util.logging.Logger;

/**
 * Starts the background job when the app starts and stops it when the app stops.
 * Runs MaintenanceJob.runOnce() every 5 minutes (first run 1 minute after startup).
 */
@WebListener
public class MaintenanceListener implements ServletContextListener {

    private static final Logger LOGGER = Logger.getLogger(MaintenanceListener.class.getName());
    private ScheduledExecutorService scheduler;

    @Override
    public void contextInitialized(ServletContextEvent sce) {
        scheduler = Executors.newSingleThreadScheduledExecutor(r -> {
            Thread t = new Thread(r, "ptc-maintenance");
            t.setDaemon(true);
            return t;
        });
        scheduler.scheduleWithFixedDelay(() -> {
            // Never let an exception escape: it would silently cancel all future runs.
            try {
                MaintenanceJob.runOnce();
            } catch (Throwable t) {
                LOGGER.log(Level.SEVERE, "Maintenance job failed", t);
            }
        }, 1, 5, TimeUnit.MINUTES);
        LOGGER.info("Maintenance job scheduled (every 5 minutes).");
    }

    @Override
    public void contextDestroyed(ServletContextEvent sce) {
        if (scheduler != null) {
            scheduler.shutdownNow();
        }
    }
}