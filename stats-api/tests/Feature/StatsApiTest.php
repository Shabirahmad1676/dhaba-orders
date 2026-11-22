<?php

namespace Tests\Feature;

use Tests\TestCase;

class StatsApiTest extends TestCase
{
    public function test_health_endpoint_returns_ok(): void
    {
        $response = $this->get('/health');
        $response->assertStatus(200)->assertJson(['status' => 'ok']);
    }

    public function test_stats_endpoint_returns_metrics(): void
    {
        $response = $this->get('/api/stats');
        $response->assertStatus(200)->assertJsonStructure([
            'orders_per_minute',
            'top_dishes',
        ]);
    }
}
