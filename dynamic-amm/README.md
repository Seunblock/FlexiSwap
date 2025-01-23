# Concentrated Liquidity AMM Protocol

A Clarity smart contract implementation of an Automated Market Maker (AMM) with concentrated liquidity features, built for the Stacks blockchain. This protocol enables efficient token swapping and liquidity provision with customizable price ranges.

## Features

- **Concentrated Liquidity Positions**: Users can provide liquidity within specific price ranges for improved capital efficiency
- **Dynamic Fee System**: Automated fee adjustment based on market volatility
- **Price Oracle**: Built-in price tracking and time-weighted average price calculations
- **Emergency Controls**: Safety features to protect users in case of emergencies
- **Protocol Fee Options**: Configurable protocol fee mechanism for sustainable development

## Technical Architecture

### Core Components

1. **Pools**
   - Unique identifier for each trading pair
   - Tracks reserves, prices, and aggregate statistics
   - Configurable tick spacing for different volatility profiles
   - Dynamic fee rate adjustment based on market conditions

2. **Positions**
   - User-specific liquidity allocations
   - Defined by upper and lower tick boundaries
   - Tracks earned fees and owed tokens
   - Position-specific metrics for accurate fee calculation

3. **Price Management**
   - Square root price framework for efficient calculations
   - Tick-based price representation
   - Oracle price tracking for time-weighted averages

### Key Constants

```clarity
MIN-LIQUIDITY: 1000000
PRECISION: 1000000 (6 decimal places)
MAX-FEE: 10000 (1% = 100 basis points)
MIN-FEE: 100 (0.01% = 1 basis point)
```

## Usage Guide

### Creating a Pool

```clarity
(create-pool token-x token-y initial-sqrt-price tick-spacing)
```

Parameters:
- `token-x`: Principal of the first token
- `token-y`: Principal of the second token
- `initial-sqrt-price`: Initial square root price (>= PRECISION)
- `tick-spacing`: Minimum tick movement (> 0)

### Adding Liquidity

```clarity
(create-position pool-id amount-x amount-y lower-tick upper-tick)
```

Parameters:
- `pool-id`: Target pool identifier
- `amount-x`: Amount of token X to add
- `amount-y`: Amount of token Y to add
- `lower-tick`: Lower price boundary (in ticks)
- `upper-tick`: Upper price boundary (in ticks)

### Performing Swaps

```clarity
(swap pool-id token-in amount-in min-amount-out)
```

Parameters:
- `pool-id`: Target pool identifier
- `token-in`: Principal of the input token
- `amount-in`: Amount to swap
- `min-amount-out`: Minimum output amount (slippage protection)

### Collecting Fees

```clarity
(collect-fees position-id)
```

Parameters:
- `position-id`: Position identifier

## Security Features

1. **Emergency Shutdown**
   - Controlled by contract owner
   - Halts all trading and liquidity provision
   - Protects users during emergencies

2. **Slippage Protection**
   - Minimum output amount enforcement
   - Dynamic fee adjustment for volatility
   - Price impact considerations

3. **Access Controls**
   - Owner-specific functions
   - Position-specific authorizations
   - Protected state modifications

## Error Codes

- `ERR-NOT-AUTHORIZED (u1000)`: Unauthorized access attempt
- `ERR-INVALID-POOL (u1001)`: Invalid pool operations
- `ERR-INSUFFICIENT-LIQUIDITY (u1002)`: Insufficient liquidity for operation
- `ERR-INVALID-POSITION (u1003)`: Invalid position parameters
- `ERR-SLIPPAGE-TOO-HIGH (u1004)`: Exceeds slippage tolerance
- `ERR-INVALID-AMOUNT (u1005)`: Invalid input amounts
- `ERR-POOL-EXISTS (u1006)`: Duplicate pool creation attempt
- `ERR-MATH-ERROR (u1007)`: Mathematical calculation error

## Query Functions

### Pool Information
```clarity
(get-pool-info pool-id)
```
Returns complete pool state including reserves, prices, and fees.

### Position Details
```clarity
(get-position-info position-id)
```
Returns position details including liquidity ranges and accumulated fees.

### Oracle Price
```clarity
(get-oracle-price pool-id)
```
Returns current time-weighted average price from the oracle.

## Development Guidelines

1. **Testing Requirements**
   - Unit tests for all core functions
   - Integration tests for complex operations
   - Property-based testing for mathematical operations

2. **Deployment Checklist**
   - [ ] Configure initial constants
   - [ ] Set contract owner
   - [ ] Verify emergency controls
   - [ ] Test oracle functionality
   - [ ] Validate fee parameters

3. **Security Considerations**
   - Regular audit of price calculations
   - Monitoring of pool imbalances
   - Verification of fee collection
   - Review of emergency procedures

## Project structure

flexiswap/
├── contracts/
│   ├── flexiswap-core.clar     # Core AMM contract (implemented)
│   │   - Pool creation/management
│   │   - Position tracking
│   │   - Swap functionality
│   │   - Oracle integration
│   │
│   ├── flexiswap-math.clar     # Math libraries (next)
│   │   - Fixed-point math
│   │   - Square root calculations 
│   │   - Tick/price conversions
│   │   - Fee calculations
│   │
│   ├── flexiswap-factory.clar  # Pool factory (future)
│   │   - Pool deployment
│   │   - Fee configuration
│   │   - Admin controls
│   │  
│   ├── flexiswap-position.clar  # Position management (future)
│   │   - Position creation
│   │   - Range orders
│   │   - Fee collection 
│   │
│   └── tests/                  # Contract tests
│
└── README.md                   # Documentation