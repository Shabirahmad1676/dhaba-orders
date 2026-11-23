import React, { useEffect, useState } from 'react';
import './App.css';

export default function App() {
  const [menu, setMenu] = useState([]);
  const [stats, setStats] = useState({ orders_per_minute: 0, top_dishes: [] });
  const [statusMsg, setStatusMsg] = useState('');
  const [orderingId, setOrderingId] = useState(null);
  const [menuLoading, setMenuLoading] = useState(true);
  const version = import.meta.env.VITE_GIT_SHA || 'dev';

  useEffect(() => {
    fetch('/api/menu')
      .then((r) => r.json())
      .then((d) => setMenu(d.items || []))
      .catch(() => {})
      .finally(() => setMenuLoading(false));

    fetch('/api/stats')
      .then((r) => r.json())
      .then((d) => setStats(d))
      .catch(() => {});
  }, []);

  const placeOrder = async (item) => {
    setOrderingId(item.id);
    setStatusMsg(`Ordering ${item.name}...`);
    try {
      const res = await fetch('/api/orders', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ item: item.name, quantity: 1 }),
      });
      if (!res.ok) throw new Error('Order failed');
      const data = await res.json();
      setStatusMsg(`Order #${data.id} placed · ${data.status}`);
    } catch {
      setStatusMsg('Could not place your order. Please try again.');
    } finally {
      setOrderingId(null);
    }
  };

  return (
    <div className="app-shell">
      <header className="topbar">
        <a className="brand" href="/" aria-label="Dhaba Orders home">
          <span className="brand-mark" aria-hidden="true">D</span>
          <span>Dhaba Orders</span>
        </a>
        <div className="header-meta">
          <span className="live-dot"><span /> Kitchen live</span>
          <span className="build-badge">Build {version.slice(0, 7)}</span>
        </div>
      </header>

      <main className="dashboard">
        {statusMsg && (
          <div className="toast" role="status">
            <span className="toast-icon" aria-hidden="true">✓</span>
            <span>{statusMsg}</span>
          </div>
        )}

        <section className="hero">
          <div>
            <p className="eyebrow">Today&apos;s kitchen</p>
            <h1>What&apos;s cooking?</h1>
            <p className="hero-copy">Fresh from the tandoor. Pick your favourite and place an order.</p>
          </div>
          <div className="hero-stat">
            <strong>{stats.orders_per_minute}</strong>
            <span>orders / min</span>
          </div>
        </section>

        <div className="content-grid">
          <section className="menu-section" aria-labelledby="menu-heading">
            <div className="section-heading">
              <div>
                <p className="eyebrow">Our selection</p>
                <h2 id="menu-heading">Menu</h2>
              </div>
              <span className="item-count">{menu.length} items</span>
            </div>

            {menuLoading ? (
              <div className="menu-grid" aria-label="Loading menu">
                {[1, 2, 3].map((item) => <div className="menu-card skeleton" key={item} />)}
              </div>
            ) : (
              <div className="menu-grid">
                {menu.map((item, index) => (
                  <article className="menu-card" key={item.id}>
                    <div className="dish-number">0{index + 1}</div>
                    <div className="dish-content">
                      <h3>{item.name}</h3>
                      <span className="price">Rs. {item.price}</span>
                      <span className="sr-only">
                        {item.name} — Rs. {item.price}
                      </span>
                    </div>
                    <button
                      type="button"
                      className="order-button"
                      onClick={() => placeOrder(item)}
                      disabled={orderingId === item.id}
                    >
                      {orderingId === item.id ? 'Adding…' : 'Order'}
                    </button>
                  </article>
                ))}
              </div>
            )}
          </section>

          <aside className="stats-panel" aria-labelledby="stats-heading">
            <div className="section-heading compact">
              <div>
                <p className="eyebrow">Right now</p>
                <h2 id="stats-heading">Kitchen activity</h2>
              </div>
            </div>

            <div className="rate-card">
              <span className="rate-label">Orders per minute</span>
              <strong>{stats.orders_per_minute}</strong>
              <div className="activity-bars" aria-hidden="true">
                {[34, 54, 42, 68, 48, 82, 62, 92, 72, 88].map((height, index) => (
                  <span key={index} style={{ height: `${height}%` }} />
                ))}
              </div>
            </div>

            <div className="top-dishes">
              <h3>Popular today</h3>
              {(stats.top_dishes || []).length ? (
                <ol>
                  {(stats.top_dishes || []).slice(0, 3).map((dish, index) => (
                    <li key={dish}>
                      <span className="rank">0{index + 1}</span>
                      <span>{dish}</span>
                    </li>
                  ))}
                </ol>
              ) : (
                <p className="empty-state">Waiting for kitchen activity</p>
              )}
            </div>
          </aside>
        </div>
      </main>
    </div>
  );
}
