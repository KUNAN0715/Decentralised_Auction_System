import { describe, it, beforeEach, expect } from 'vitest';

// Mocking the Auction contract for testing purposes
const mockAuction = {
  state: {
    highestBid: 0,
    highestBidder: null,
    auctionEnd: 0,
    auctionOwner: null,
  },
  startAuction: (duration: number, caller: any) => {
    if (mockAuction.state.auctionOwner) {
      return { error: 101 }; // Auction already started
    }
    mockAuction.state.auctionEnd = duration;
    mockAuction.state.auctionOwner = caller;
    return { value: "Auction started" };
  },
  placeBid: (amount: number, bidder: any) => {
    if (mockAuction.state.auctionEnd === 0) {
      return { error: 102 }; // Auction has ended
    }
    if (amount <= mockAuction.state.highestBid) {
      return { error: 103 }; // Bid too low
    }
    mockAuction.state.highestBid = amount;
    mockAuction.state.highestBidder = bidder;
    return { value: "Bid placed" };
  },
  endAuction: (caller: any) => {
    if (mockAuction.state.auctionEnd > 0) {
      return { error: 104 }; // Auction still ongoing
    }
    if (mockAuction.state.auctionOwner !== caller) {
      return { error: 105 }; // Only the auction owner can end the auction
    }
    return { value: mockAuction.state.highestBidder };
  },
};

describe('Auction Contract', () => {
  let user1: string;
  let user2: string;

  beforeEach(() => {
    // Initialize mock state and user principals
    user1 = 'ST1234...'; // User 1 principal
    user2 = 'ST5678...'; // User 2 principal

    // Reset the mock auction state
    mockAuction.state = {
      highestBid: 0,
      highestBidder: null,
      auctionEnd: 0,
      auctionOwner: null,
    };
  });

  it('should allow a user to start an auction', () => {
    const result = mockAuction.startAuction(100, user1);
    expect(result).toEqual({ value: "Auction started" });
    expect(mockAuction.state.auctionOwner).toBe(user1);
    expect(mockAuction.state.auctionEnd).toBe(100);
  });

  it('should prevent a second auction from being started', () => {
    mockAuction.startAuction(100, user1);
    const result = mockAuction.startAuction(100, user2);
    expect(result).toEqual({ error: 101 });
    expect(mockAuction.state.auctionOwner).toBe(user1);
  });

  it('should allow a user to place a higher bid', () => {
    mockAuction.startAuction(100, user1);
    const result = mockAuction.placeBid(100, user2);
    expect(result).toEqual({ value: "Bid placed" });
    expect(mockAuction.state.highestBid).toBe(100);
    expect(mockAuction.state.highestBidder).toBe(user2);
  });

  it('should prevent a user from placing a bid lower than the highest bid', () => {
    mockAuction.startAuction(100, user1);
    mockAuction.placeBid(100, user2); // First bid
    const result = mockAuction.placeBid(50, user1); // Low bid
    expect(result).toEqual({ error: 103 });
    expect(mockAuction.state.highestBid).toBe(100);
    expect(mockAuction.state.highestBidder).toBe(user2);
  });

  it('should prevent bidding after the auction has ended', () => {
    mockAuction.startAuction(100, user1);
    mockAuction.state.auctionEnd = 0; // Simulating auction end
    const result = mockAuction.placeBid(200, user2);
    expect(result).toEqual({ error: 102 });
  });

  it('should allow the auction owner to end the auction and return the highest bidder', () => {
    mockAuction.startAuction(100, user1);
    mockAuction.placeBid(100, user2);
    mockAuction.state.auctionEnd = 0; // Simulating auction end
    const result = mockAuction.endAuction(user1);
    expect(result).toEqual({ value: user2 });
  });

  it('should prevent a non-owner from ending the auction', () => {
    mockAuction.startAuction(100, user1);
    mockAuction.placeBid(100, user2);
    mockAuction.state.auctionEnd = 0; // Simulating auction end
    const result = mockAuction.endAuction(user2); // Non-owner attempting to end
    expect(result).toEqual({ error: 105 });
  });

  it('should prevent ending the auction while it is still ongoing', () => {
    mockAuction.startAuction(100, user1);
    const result = mockAuction.endAuction(user1);
    expect(result).toEqual({ error: 104 });
  });
});
