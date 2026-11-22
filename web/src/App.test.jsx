import React from 'react';
import { render, screen } from '@testing-library/react';
import { describe, expect, it, vi } from 'vitest';
import App from './App.jsx';

describe('Dhaba Web App', () => {
  it('renders heading and menu items from /api/menu', async () => {
    globalThis.fetch = vi.fn((url) =>
      Promise.resolve({
        ok: true,
        json: () =>
          Promise.resolve(
            url === '/api/menu'
              ? { items: [{ id: 1, name: 'Chicken Karahi', price: 1200 }] }
              : { orders_per_minute: 4, top_dishes: ['Chicken Karahi'] }
          ),
      })
    );

    render(<App />);
    expect(screen.getByText('Dhaba Orders')).toBeTruthy();
    expect(await screen.findByText(/Chicken Karahi — Rs\. 1200/)).toBeTruthy();
  });
});
