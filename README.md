# Real Estate Tokenization Smart Contract

This repository contains a smart contract for the tokenization of real estate assets via NFTs on a blockchain. The contract allows property owners and administrators to manage property ownership, registration, transfer, and other relevant information in a secure and decentralized manner.

### Features

- **Property Registration**: Admins can register single or multiple properties and assign metadata such as property description and classification.
- **Ownership Management**: Each property is tokenized as a non-fungible token (NFT), which maps to an owner address.
- **Property Transfer**: Property owners can transfer ownership of properties securely. The contract supports transfer restrictions like locked properties and pre-approved buyer whitelisting.
- **Property Listing**: Property owners can list properties for sale or remove them from the market.
- **Insurance & Maintenance Management**: Allows property owners to manage insurance details and track maintenance history.
- **Market Valuation**: Properties can be assigned market value and historical valuations can be tracked.
- **Voting Mechanism**: Property owners can vote on decisions regarding their properties.
- **Compliance & Security**: The contract ensures compliance and can enhance security during the transfer process.

### Smart Contract Structure

- **Admin Controls**: Only the admin address can perform critical operations like registering properties, setting global tax rates, etc.
- **NFTs for Real Estate**: Each property is represented as a unique NFT.
- **Property Metadata**: Store and update property details such as location, classification, and maintenance records.
- **Transfers and Market Listings**: Manage the sale and transfer process, including lock/unlock mechanisms for properties and listing on the marketplace.
- **Advanced Features**: The contract includes features for handling rental agreements, insurance claims, tax calculations, and more.

### Installation

To deploy this contract on a blockchain network, ensure that you have the necessary environment and dependencies installed. This contract is written in **Clarity**, which is the smart contract language for the Stacks blockchain. 

1. Install [Clarinet](https://book.clarinet.app) (a local development environment for Stacks).
2. Clone this repository to your local machine:
   ```bash
   git clone https://github.com/yourusername/real-estate-tokenization-smart-contract.git
   cd real-estate-tokenization-smart-contract
   ```
3. Deploy the contract using Clarinet or your preferred Clarity development tools.

### Functions Overview

#### Property Registration

- `register-new-property(metadata)` — Registers a single property with metadata.
- `register-multiple-properties(property-descriptions)` — Registers multiple properties at once.

#### Property Transfer

- `execute-property-transfer(asset-id, new-owner)` — Transfers ownership of a property.
- `lock-property-transfers(asset-id)` — Locks a property to prevent further transfers.
- `unlock-property-transfers(asset-id)` — Unlocks a property for transfer.

#### Market Listing

- `publish-property-listing(asset-id)` — Makes a property available for sale.
- `withdraw-property-listing(asset-id)` — Removes a property from the sale listing.

#### Metadata Management

- `update-property-metadata(asset-id, metadata)` — Updates metadata for an existing property.
- `set-property-classification(asset-id, classification)` — Assigns a classification to the property (e.g., residential, commercial).
- `set-property-coordinates(asset-id, location)` — Sets the location details of the property.

#### Property Validation

- `get-current-property-owner(asset-id)` — Retrieves the current owner of a property.
- `get-property-details(asset-id)` — Fetches the stored metadata of a property.

### Error Codes

- `error-admin-only (u100)` — Only accessible by the admin.
- `error-unauthorized-property-action (u101)` — The caller is not the property owner.
- `error-duplicate-property (u102)` — Property already exists.
- `error-property-unknown (u103)` — The referenced property does not exist.
- `error-recipient-invalid (u104)` — Invalid recipient address for transfer.
- `error-property-locked (u105)` — The property is locked and cannot be transferred.
- `error-property-metadata-invalid (u106)` — Invalid metadata (either empty or exceeds size limits).

### Test Functions

To test the contract's functionality, you can use the provided test functions. Example:
- `test-registration-process` — Verifies the property registration process works as expected.
- `test-property-transfer(asset-id, recipient)` — Tests property transfer functionality.

### Contributing

If you would like to contribute, please fork the repository, create a new branch, and submit a pull request with your proposed changes.

### License

This project is licensed under the MIT License.

### Acknowledgments

This contract is designed for educational and real-world use in the context of property tokenization and blockchain technology.
