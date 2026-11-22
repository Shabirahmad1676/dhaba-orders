import React, { useEffect, useState } from 'react';

export default function App() {
  const [menu, setMenu] = useState([]);
  const [stats, setStats] = useState({ orders_per_minute: 0, top_dishes: [] });
  const [statusMsg, setStatusMsg] = useState('');
  const version = import.meta.env.VITE_GIT_SHA || 'dev';

  useEffect(() => {
    fetch('/api/menu')
      .then((r) => r.json())
      .then((d) => setMenu(d.items || []))
      .catch(() => {});

    fetch('/api/stats')
      .then((r) => r.json())
      .then((d) => setStats(d))
      .catch(() => {});
  }, []);

  const placeOrder = async (itemName) => {
    setStatusMsg(`Ordering ${itemName}...`);
    try {
      const res = await fetch('/api/orders', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ item: itemName, quantity: 1 }),
      });
      if (!res.ok) throw new Error('Order failed');
      const data = await res.json();
      setStatusMsg(`Order #${data.id} placed (${data.status})`);
    } catch {
      setStatusMsg('Failed to place order');
    }
  };

  return (
    <main style={{ fontFamily: 'sans-serif', maxWidth: 680, margin: '2rem auto', padding: '0 1rem' }}>
      <h1>Dhaba Orders</h1>
      <p><small>Build: {version}</small></p>
      {statusMsg && <p role="status"><strong>{statusMsg}</strong></p>}

      <section>
        <h2>Menu</h2>
        <ul>
          {menu.map((m) => (
            <li key={m.id} style={{ marginBottom: '0.5rem' }}>
              {m.name} — Rs. {m.price}{' '}
              <button type="button" onClick={() => placeOrder(m.name)}>Order</button>
            </li>
          ))}
        </ul>
      </section>

      <section>
        <h2>Live Kitchen Stats</h2>
        <p>Orders / min: {stats.orders_per_minute}</p>
        <p>Top dishes: {(stats.top_dishes || []).join(', ')}</p>
      </section>
    </main>
  );
}
