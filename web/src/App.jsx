import { useEffect, useState, useCallback } from 'react';
import './App.css';

export default function App() {
  const [menu, setMenu] = useState([]);
  const [orders, setOrders] = useState([]);
  const [stats, setStats] = useState({ orders_per_minute: 0, top_dishes: [] });
  const [quantities, setQuantities] = useState({});
  const [submitting, setSubmitting] = useState(null);

  const fetchData = useCallback(async () => {
    try {
      const [ordersRes, statsRes] = await Promise.all([
        fetch('/api/orders'),
        fetch('/api/stats'),
      ]);
      if (ordersRes.ok) {
        const ordersData = await ordersRes.json();
        if (Array.isArray(ordersData)) setOrders(ordersData);
      }
      if (statsRes.ok) {
        const statsData = await statsRes.json();
        setStats(statsData);
      }
    } catch {
      // Ignore transient network errors during rolling updates
    }
  }, []);

  useEffect(() => {
    fetch('/api/menu')
      .then((res) => res.json())
      .then((data) => {
        const items = data.items || [];
        setMenu(items);
        const initialQty = {};
        items.forEach((item) => {
          initialQty[item.id] = 1;
        });
        setQuantities(initialQty);
      })
      .catch(() => {});

    fetchData();
    const interval = setInterval(fetchData, 2000);
    return () => clearInterval(interval);
  }, [fetchData]);

  const placeOrder = async (dish) => {
    const quantity = Math.max(1, Number(quantities[dish.id] || 1));
    setSubmitting(dish.id);
    try {
      const res = await fetch('/api/orders', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ item: dish.name, quantity }),
      });
      if (res.ok) {
        await fetchData();
      }
    } finally {
      setSubmitting(null);
    }
  };

  return (
    <div className="container">
      <header className="header">
        <div>
          <h1>Dhaba Orders</h1>
          <p>Live Kitchen &amp; Order Dispatch</p>
        </div>
      </header>

      <section className="stats-bar">
        <div className="stat-card">
          <div className="stat-label">Orders / Minute</div>
          <div className="stat-value">{stats.orders_per_minute ?? 0}</div>
        </div>
        <div className="stat-card">
          <div className="stat-label">Recent Orders</div>
          <div className="stat-value">{orders.length}</div>
        </div>
        <div className="stat-card">
          <div className="stat-label">Popular Dishes</div>
          <div className="stat-value" style={{ fontSize: '1rem', paddingTop: '0.3rem' }}>
            {stats.top_dishes?.length ? stats.top_dishes.join(', ') : '—'}
          </div>
        </div>
      </section>

      <main className="grid">
        <section className="panel">
          <h2 className="panel-title">Menu</h2>
          <div className="menu-list">
            {menu.map((dish) => (
              <div key={dish.id} className="menu-item">
                <div>
                  <div className="dish-name">{dish.name}</div>
                  <div className="dish-price">PKR {dish.price}</div>
                </div>
                <div className="order-controls">
                  <input
                    type="number"
                    min="1"
                    max="20"
                    aria-label={`Quantity for ${dish.name}`}
                    className="qty-input"
                    value={quantities[dish.id] ?? 1}
                    onChange={(e) =>
                      setQuantities({ ...quantities, [dish.id]: e.target.value })
                    }
                  />
                  <button
                    className="btn"
                    disabled={submitting === dish.id}
                    onClick={() => placeOrder(dish)}
                  >
                    {submitting === dish.id ? 'Sending...' : 'Order'}
                  </button>
                </div>
              </div>
            ))}
          </div>
        </section>

        <section className="panel">
          <h2 className="panel-title">
            <span>Live Orders</span>
            <span style={{ fontSize: '0.78rem', color: 'var(--muted)', fontWeight: 400 }}>
              Auto-syncs every 2s
            </span>
          </h2>
          {orders.length === 0 ? (
            <div className="empty-state">No orders yet. Select a dish to place an order.</div>
          ) : (
            <div className="orders-list">
              {orders.map((order) => (
                <div key={order.id} className="order-row">
                  <div>
                    <div className="dish-name">
                      #{order.id} · {order.item}
                    </div>
                    <div className="order-meta">Qty: {order.quantity || 1}</div>
                  </div>
                  <span
                    className={`badge ${
                      order.status === 'ready' ? 'badge-ready' : 'badge-new'
                    }`}
                  >
                    {order.status}
                  </span>
                </div>
              ))}
            </div>
          )}
        </section>
      </main>
    </div>
  );
}
