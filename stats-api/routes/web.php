<?php

use Illuminate\Support\Facades\Redis;
use Illuminate\Support\Facades\Route;

Route::get('/health', function () {
    return response()->json([
        'status' => 'ok',
        'service' => 'stats-api',
        'version' => env('GIT_SHA', 'dev'),
    ]);
});

Route::get('/api/stats', function () {
    $ordersPerMinute = 0;
    $topDishes = ['Chicken Karahi', 'Mutton Shinwari'];

    if (env('REDIS_HOST')) {
        try {
            $ordersPerMinute = (int) (Redis::get('stats:orders_per_min') ?? 0);
            $cachedTop = Redis::lrange('stats:top_dishes', 0, 4);
            if (!empty($cachedTop)) {
                $topDishes = $cachedTop;
            }
        } catch (\Throwable $e) {
            // Fallback gracefully if Redis is unreachable during isolated tests
        }
    }

    return response()->json([
        'orders_per_minute' => $ordersPerMinute,
        'top_dishes' => $topDishes,
    ]);
});
