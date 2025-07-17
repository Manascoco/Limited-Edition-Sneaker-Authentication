# 👟 Limited Edition Sneaker Authentication

A blockchain-based authentication system for limited edition sneakers using Stacks and Clarity smart contracts. This system pairs physical sneakers with NFTs to provide tamper-proof authenticity verification.

## 🚀 Features

- **NFT Minting**: Authorized manufacturers can mint unique NFTs for each sneaker
- **Authenticity Verification**: Physical hash matching ensures authenticity
- **Manufacturer Authorization**: Only authorized manufacturers can mint tokens
- **Transfer Tracking**: Complete ownership history with timestamps
- **Verification Requests**: Users can request authenticity verification
- **Contract Governance**: Pause/unpause functionality for emergencies

## 📋 Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Node.js and npm
- Stacks wallet for testing

## 🛠️ Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd Limited-Edition-Sneaker-Authentication
```

2. Install dependencies:
```bash
npm install
```

3. Run tests:
```bash
clarinet test
```

## 💻 Usage

### For Manufacturers 🏭

1. **Get Authorization**: Contract owner must authorize your principal
2. **Mint Sneaker NFT**: Create NFT with sneaker details and physical hash
3. **Verify Authenticity**: Complete verification requests from users

### For Sneaker Owners 👤

1. **Verify Authenticity**: Use physical hash to verify your sneaker
2. **Transfer Ownership**: Send NFT to new owner
3. **Request Verification**: Ask for manufacturer verification
4. **Check History**: View complete ownership and verification history

## 🔧 Smart Contract Functions

### Public Functions

#### `authorize-manufacturer (manufacturer principal)`
Authorize a manufacturer to mint sneaker NFTs (owner only)

#### `mint-sneaker-nft (recipient brand model size color serial-number physical-hash metadata-uri)`
Mint a new sneaker NFT with complete sneaker data

#### `transfer (token-id sender recipient)`
Transfer NFT ownership between users

#### `verify-authenticity (token-id physical-hash)`
Verify sneaker authenticity using physical hash

#### `request-verification (token-id)`
Request verification from authorized manufacturers

#### `complete-verification (token-id is-authentic)`
Complete verification request (manufacturers only)

### Read-Only Functions

#### `get-sneaker-data (token-id)`
Get complete sneaker information

#### `get-sneaker-history (token-id)`
Get ownership and verification history

#### `get-owner (token-id)`
Get current NFT owner

#### `is-manufacturer-authorized (manufacturer)`
Check if manufacturer is authorized

## 📝 Contract Constants

- `CONTRACT_OWNER`: Contract deployer address
- `ERR_NOT_AUTHORIZED`: Unauthorized access error (401)
- `ERR_NOT_FOUND`: Token not found error (404)
- `ERR_ALREADY_EXISTS`: Resource already exists error (409)
- `ERR_INVALID_PARAMS`: Invalid parameters error (400)

## 🧪 Testing

Run the test suite:
```bash
clarinet test
```

Check contract syntax:
```bash
clarinet check
```

## 🔐 Security Features

- **Authorization Control**: Only authorized manufacturers can mint
- **Physical Hash Verification**: Prevents counterfeit authentication
- **Ownership Validation**: Ensures only owners can transfer
- **Pause Mechanism**: Emergency contract pause capability
- **History Tracking**: Immutable record of all actions

## 📊 Data Structures

### Sneaker Data
- Brand, model, size, color
- Serial number and manufacturer
- Authentication date and status
- Physical hash for verification
- Metadata URI for additional info

### History Entry
- Action type and timestamp
- Actor principal and details
- Chronological tracking

## 🎯 Use Cases

1. **Luxury Sneaker Brands**: Authenticate limited releases
2. **Secondary Markets**: Verify authenticity before purchase
3. **Collectors**: Prove ownership and authenticity
4. **Retailers**: Eliminate counterfeit products
5. **Insurance**: Verify value for coverage

## 📈 Future Enhancements

- Integration with physical NFC tags
- Mobile app for QR code scanning
- Marketplace integration
- Multi-signature verification
- Batch minting capabilities

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Support

For questions or issues:
- Open an issue on GitHub
- Check the documentation
- Contact the development team

---

**Built with ❤️ using Stacks and Clarity**
