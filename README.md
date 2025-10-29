# 🏢 Shared Resource Booking System

A decentralized resource booking platform built on Stacks blockchain using Clarity smart contracts. This system enables users to create, book, and manage shared resources with secure payment processing and automated fee distribution.

## ✨ Features

- 📦 **Resource Management**: Create and manage bookable resources with customizable pricing
- 🎫 **Booking System**: Time-based resource booking with conflict prevention
- 💰 **Automated Payments**: STX-based payments with platform fee distribution
- 📊 **Analytics**: Track booking statistics and resource performance
- ⭐ **Rating System**: Add reviews and ratings for resources
- 🔐 **Access Control**: Owner-based resource management and admin functions

## 🚀 Contract Functions

### Public Functions

#### Resource Management
- `create-resource`: Create a new bookable resource
- `update-resource`: Update resource details (owner only)

#### Booking Operations
- `book-resource`: Book a resource for a specific time period
- `cancel-booking`: Cancel an existing booking with refund
- `complete-booking`: Mark a booking as completed and distribute payments

#### Reviews & Ratings
- `add-review`: Add a rating (1-5 stars) for a resource

#### Admin Functions
- `set-platform-fee`: Update platform fee percentage (owner only)
- `transfer-ownership`: Transfer contract ownership
- `withdraw-fees`: Withdraw accumulated platform fees (owner only)

### Read-Only Functions

#### Data Retrieval
- `get-resource`: Get resource details by ID
- `get-booking`: Get booking details by ID
- `get-user-stats`: Get user's booking statistics
- `get-resource-stats`: Get resource performance metrics

#### System Info
- `get-platform-fee`: Current platform fee percentage
- `get-contract-owner`: Contract owner address
- `get-contract-balance`: Contract STX balance
- `is-resource-booked-at`: Check if resource is booked at specific time
- `get-booking-at-time`: Get booking ID at specific time slot

## 💻 Usage Examples

### Creating a Resource
```clarity
(contract-call? .shared-resource-booking-system create-resource 
  "Conference Room A" 
  "Modern conference room with AV equipment" 
  u100 
  "meeting-room" 
  u8)
```

### Booking a Resource
```clarity
(contract-call? .shared-resource-booking-system book-resource 
  u1 
  u1000 
  u4)
```

### Adding a Review
```clarity
(contract-call? .shared-resource-booking-system add-review 
  u1 
  u5)
```

## 🏗️ Architecture

### Data Structures

#### Resources
```clarity
{
  name: (string-ascii 50),
  description: (string-ascii 200),
  owner: principal,
  price-per-hour: uint,
  active: bool,
  category: (string-ascii 30),
  max-booking-duration: uint,
  created-at: uint
}
```

#### Bookings
```clarity
{
  resource-id: uint,
  user: principal,
  start-time: uint,
  end-time: uint,
  total-cost: uint,
  status: (string-ascii 20),
  created-at: uint,
  payment-made: bool
}
```

### Key Features

- **Time Slot Management**: Prevents double-booking using active-bookings map
- **Automatic Fee Distribution**: Platform fees automatically sent to contract owner
- **Flexible Duration**: Resources can set maximum booking duration limits
- **Statistics Tracking**: Comprehensive stats for users and resources
- **Rating System**: 5-star rating system with average calculation

## 🔧 Deployment

1. **Prerequisites**
   - Install [Clarinet](https://docs.hiro.so/clarinet)
   - Ensure you have a Stacks wallet

2. **Deploy Contract**
   ```bash
   clarinet deployments generate --simnet
   clarinet deployments apply -p deployments/default.simnet-plan.yaml
   ```

3. **Verify Deployment**
   ```bash
   clarinet check
   ```

## 🧪 Testing

Run the test suite:
```bash
npm install
npm test
```

## 🔐 Security Considerations

- ✅ All user inputs are validated
- ✅ Authorization checks on sensitive operations
- ✅ Reentrancy protection through proper state management
- ✅ Integer overflow protection with uint safety
- ✅ Access control for administrative functions

## 💡 Use Cases

- **Co-working Spaces**: Book desks, meeting rooms, equipment
- **Vehicle Sharing**: Share cars, bikes, scooters
- **Equipment Rental**: Tools, cameras, electronics
- **Event Venues**: Meeting halls, conference rooms
- **Storage Units**: Temporary storage solutions

## 📈 Platform Metrics

- Default platform fee: 0.5%
- Maximum booking duration: 168 hours (1 week)
- Payment currency: STX tokens
- Rating scale: 1-5 stars

## 🤝 Contributing

Contributions are welcome! Please read our contributing guidelines and submit pull requests for any improvements.

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

---

*Built with ❤️ on Stacks blockchain*
