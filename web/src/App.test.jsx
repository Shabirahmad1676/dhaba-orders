import React from 'react';
import { render, screen } from '@testing-library/react';
import { describe, expect, it, vi } from 'vitest';
import App from './App.jsx';

describe('Dhaba Web App', () => {
  it('renders heading and menu items from /api/menu', async () => {
    vi.spyOn(window, 'fetch').mockImplementation((url) => {
      const target = String(url);
      if (target.includes('/api/menu')) {
        return Promise.resolve({
          ok: true,
          json: () => Promise.resolve({ items: [{ id: 1, name: 'Chicken Karahi', price: 1200 }] }),
        });
      }
      if (target.includes('/api/orders')) {
        return Promise.resolve({
          ok: true,
          json: () => Promise.resolve([]),
        });
      }
      return Promise.resolve({
        ok: true,
        json: () => Promise.resolve({ orders_per_minute: 4, top_dishes: ['Chicken Karahi'] }),
      });
    });

    render(<App />);
    expect(screen.getByText('Dhaba Orders')).toBeTruthy();
    expect(await screen.findByText('Chicken Karahi')).toBeTruthy();
    expect(await screen.findByText('PKR 1200')).toBeTruthy();
  });
});
