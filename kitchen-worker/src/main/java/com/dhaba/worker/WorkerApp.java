package com.dhaba.worker;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.util.List;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;
import redis.clients.jedis.Jedis;
import redis.clients.jedis.JedisPool;

public class WorkerApp {
    public static final String HEARTBEAT_KEY = "worker:heartbeat";
    public static final String QUEUE_KEY = "orders_queue";

    public static String nextOrderStatus(String currentStatus) {
        return switch (currentStatus) {
            case "new" -> "cooking";
            case "cooking" -> "ready";
            default -> "ready";
        };
    }

    public static void main(String[] args) {
        String redisHost = System.getenv().getOrDefault("REDIS_HOST", "redis");
        int redisPort = Integer.parseInt(System.getenv().getOrDefault("REDIS_PORT", "6379"));
        String dbUrl = System.getenv().getOrDefault("JDBC_DATABASE_URL", "");
        String version = System.getenv().getOrDefault("GIT_SHA", "dev");

        // Healthcheck mode: exits 0 if heartbeat key exists in Redis, 1 otherwise
        if (args.length > 0 && "--healthcheck".equals(args[0])) {
            try (Jedis jedis = new Jedis(redisHost, redisPort)) {
                System.exit(jedis.exists(HEARTBEAT_KEY) ? 0 : 1);
            } catch (Exception e) {
                System.exit(1);
            }
        }

        System.out.println("kitchen-worker starting (version=" + version + ")");
        try (JedisPool pool = new JedisPool(redisHost, redisPort)) {
            ScheduledExecutorService scheduler = Executors.newSingleThreadScheduledExecutor();
            scheduler.scheduleAtFixedRate(() -> {
                try (Jedis j = pool.getResource()) {
                    j.setex(HEARTBEAT_KEY, 15, String.valueOf(System.currentTimeMillis()));
                } catch (Exception e) {
                    System.err.println("Heartbeat failed: " + e.getMessage());
                }
            }, 0, 10, TimeUnit.SECONDS);

            while (!Thread.currentThread().isInterrupted()) {
                try (Jedis j = pool.getResource()) {
                    List<String> job = j.brpop(5, QUEUE_KEY);
                    if (job != null && job.size() == 2) {
                        int orderId = Integer.parseInt(job.get(1));
                        processOrder(dbUrl, orderId);
                    }
                } catch (Exception e) {
                    System.err.println("Queue poll error: " + e.getMessage());
                    Thread.sleep(2000);
                }
            }
        } catch (InterruptedException ie) {
            Thread.currentThread().interrupt();
        }
    }

    private static void processOrder(String dbUrl, int orderId) {
        if (dbUrl.isEmpty()) return;
        try (Connection conn = DriverManager.getConnection(dbUrl);
             PreparedStatement ps = conn.prepareStatement("UPDATE orders SET status = ? WHERE id = ?")) {
            ps.setString(1, nextOrderStatus("new"));
            ps.setInt(2, orderId);
            ps.executeUpdate();
            Thread.sleep(1000);
            ps.setString(1, nextOrderStatus("cooking"));
            ps.setInt(2, orderId);
            ps.executeUpdate();
        } catch (Exception e) {
            System.err.println("DB update failed for order " + orderId + ": " + e.getMessage());
        }
    }
}
