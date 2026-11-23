package com.dhaba.worker;

import static org.junit.jupiter.api.Assertions.assertEquals;
import org.junit.jupiter.api.Test;

class WorkerAppTest {
    @Test
    void testOrderStatusTransitions() {
        assertEquals("cooking", WorkerApp.nextOrderStatus("new"));
        assertEquals("ready", WorkerApp.nextOrderStatus("cooking"));
        assertEquals("ready", WorkerApp.nextOrderStatus("ready"));
    }

    @Test
    void testExtractOrderId() {
        assertEquals(44, WorkerApp.extractOrderId("{\"id\":44,\"item\":\"Garlic Naan\",\"quantity\":1}"));
        assertEquals(12, WorkerApp.extractOrderId("12"));
    }
}
