import { describe, it, expect, beforeEach } from 'vitest';

// Mock contract state to simulate deployment and interactions
let auctionOwner: string;
let highestBid: number;
let highestBidder: string | null;
let auctionEnd: number;
let minimumStartBid: number;
let canWithdraw: boolean;
let reservePrice: number;

beforeEach(() => {
  // Reset contract state before each test
  auctionOwner = '';
  highestBid = 0;
  highestBidder = null;
  auctionEnd = 0;
  minimumStartBid = 100;
  canWithdraw = true;
  reservePrice = 0;
});

// Helper functions to simulate contract methods
function startAuctionAdvanced(duration: number, startingBid: number, sender: string) {
  if (auctionOwner) return { ok: false, error: 'Auction already started' };
  if (startingBid < minimumStartBid) return { ok: false, error: 'Starting bid too low' };

  auctionOwner = sender;
  highestBid = startingBid;
  auctionEnd = duration;

  return { ok: 'Auction started' };
}

function withdrawBid(sender: string) {
  if (!canWithdraw) return { ok: false, error: 'Withdrawals not allowed' };
  if (sender !== highestBidder) return { ok: false, error: 'Not highest bidder' };

  highestBid = 0;
  highestBidder = null;

  return { ok: 'Bid withdrawn successfully' };
}

function setReservePrice(price: number, sender: string) {
  if (sender !== auctionOwner) return { ok: false, error: 'Only auction owner can set reserve price' };

  reservePrice = price;

  return { ok: 'Reserve price set successfully' };
}

// Tests
describe('Auction Contract Tests', () => {
  describe('startAuctionAdvanced', () => {
    it('should start the auction with a valid starting bid', () => {
      const result = startAuctionAdvanced(10, 200, 'owner');
      expect(result.ok).toBe('Auction started');
      expect(auctionOwner).toBe('owner');
      expect(highestBid).toBe(200);
      expect(auctionEnd).toBe(10);
    });

    it('should not start the auction if it has already started', () => {
      startAuctionAdvanced(10, 200, 'owner');
      const result = startAuctionAdvanced(20, 300, 'owner');
      expect(result.ok).toBe(false);
      expect(result.error).toBe('Auction already started');
    });

    it('should not start the auction with a bid below the minimum start bid', () => {
      const result = startAuctionAdvanced(10, 50, 'owner');
      expect(result.ok).toBe(false);
      expect(result.error).toBe('Starting bid too low');
    });
  });

  describe('withdrawBid', () => {
    it('should allow the highest bidder to withdraw their bid', () => {
      auctionOwner = 'owner';
      highestBid = 500;
      highestBidder = 'user_1';
      const result = withdrawBid('user_1');
      expect(result.ok).toBe('Bid withdrawn successfully');
      expect(highestBid).toBe(0);
      expect(highestBidder).toBe(null);
    });

    it('should not allow withdrawal if not the highest bidder', () => {
      auctionOwner = 'owner';
      highestBid = 500;
      highestBidder = 'user_1';
      const result = withdrawBid('user_2');
      expect(result.ok).toBe(false);
      expect(result.error).toBe('Not highest bidder');
    });

    it('should not allow withdrawal if withdrawals are disabled', () => {
      auctionOwner = 'owner';
      highestBid = 500;
      highestBidder = 'user_1';
      canWithdraw = false;
      const result = withdrawBid('user_1');
      expect(result.ok).toBe(false);
      expect(result.error).toBe('Withdrawals not allowed');
    });
  });

  describe('setReservePrice', () => {
    it('should allow the auction owner to set the reserve price', () => {
      auctionOwner = 'owner';
      const result = setReservePrice(1000, 'owner');
      expect(result.ok).toBe('Reserve price set successfully');
      expect(reservePrice).toBe(1000);
    });

    it('should not allow non-owners to set the reserve price', () => {
      auctionOwner = 'owner';
      const result = setReservePrice(1000, 'user_1');
      expect(result.ok).toBe(false);
      expect(result.error).toBe('Only auction owner can set reserve price');
    });
  });
});
