# Decentralease

An NFT renting and leasing protocol to power the next generation of digital asset rights.

## Inspiration

Utility NFTs are destined to play a critical role in the next generation of web3 dApps. However, current NFT implementations are flawed in that they are relatively illiquid and impose high financial barriers to entry.

My inspiration for Decentralease came from my interest in Web3 games, which are destined to utilize NFTs in some form. As a curious gamer myself, I have wanted to 'try' several Web3 games before without wanting to commit the capital to 'buy' the required assets. Thus, I set out to create an NFT renting marketplace.

In my search for existing rental protocols, I came across two existing implementations:

- Collateralized renting
- Smart contract wallets

While both seemed viable, the former fails to address the barrier to entry problem and the latter suffers from the need for perpetual maintenance and overcomplexity. Then, I saw the news of the finalization of the newest ERC standard: ERC-4907. ERC-4907 standardizes the creation of rentable NFTs by adding a separate **user** role in addition to the existing **owner** role. Thus, an asset **owner** can rent their assets to renters by setting the **user** address on the contract to the renter's address. As I realized the importance of this new standard, I set out to build a rental marketplace on top of it.

## What it does

Decentralease is an NFT renting and leasing protocol built on the novel ERC-4907 standard. ERC-4907 is an extension of ERC-721 which adds an additional "user" role, separating ownership and usage rights. This enables the asset owner to assign a user without giving up ownership privileges.

The two main user groups on Decentralease are **asset owners** and **asset renters**.

### Asset Owners

Asset owners hold digital assets. Currently, many assets are underutilized, as a lack of active usage means the asset is essentially frozen. With the ability to rent, asset owners can earn income on their assets while they are idle. For instance, an Axie Infinity player with hundreds of characters can rent out their reserve characters as they are unable to use all of their assets at once. Further, rental ability unlocks liquidity for NFTs. For the same Axie player, the only way he/she can currently liquidate their characters is by selling them, a permanent action. With Decentralease, he/she can rent out these assets without permanently selling the asset.

### Asset Renters

Asset renters want to use digital assets in dApps, but do not own the asset. Through Decentralease, they can use the dApp without purchasing the asset. This lowers barriers to entry for the renter, allowing them to temporarily 'try out' an asset before fully committing to a purchase.

## How I built it

Decentralease's architecture is separated into two categories:

1. Contracts
2. Client

### Contracts

The two most important contracts for Decentralease are `ComplexDoNFT.sol` and `Marketplace.sol`.

#### ComplexDoNFT

ComplexDoNFT is a wrapper that enables an ERC-4907 token to be listed in the marketplace. A unique ComplexDoNFT contract must be deployed for each ERC-4907 contract that is listed on the Marketplace. This contract is necessary, as opposed to directly interfacing with the ERC-4907 contract, to ensure that the owner of the asset cannot freely set the user while a token is under an active rent. The process of interfacing with the ComplexDoNFT is as follows:

1. ERC-4907 contract owner creates a new ComplexDoNFT by specifying the original contract address and market address
2. Owners of tokens from the original collection 'stake' their tokens to the ComplexDoNFT contract and receive a vNFT (Voucher NFT) which can be redeemed to reclaim the original token
3. Owner of a vNFT list their token for rent through the marketplace
4. Renter fulfills an order through the marketplace and receives a temporary doNFT, which allows them to freely set the user on the original contract.
5. Asset owner reclaims their original NFT by burning their vNFT. This can only be done if there are no outstanding doNFTs for the current timestamp.

#### Marketplace

The marketplace contract handles rental listings and the creation of doNFTs (described in previous section). Lenders can list their assets for rent using the `createLendOrder` method on the contract by specifying the maximum available duration and a set of variable-rate pricing brackets. Renters can rent assets using the `fulfillOrderNow` method, which mints a doNFT to the renter. This requires payment from the renter in the lender's currency of choice. The doNFT allows the renter to freely set the **user** role on the original asset.

### Client

The client is a React app built on top of the Next.js framework. The client requires a connection to the correct network, which in this case is the BitTorrent Chain Donau testnet. The app will redirect you to the correct chain if you connected to the wrong chain. Currently, the client supports Metamask and Coinbase wallets, with more integrations to come.

## Challenges I ran into

The biggest challenge I rant into was that there are very few protocols which use ERC-4907 - the standard was finalized less than a month ago. Thus, I had to create my own ERC-4907 tokens and applications of those tokens in order to ensure that the protocol was working properly. I envision more widespread adoption of the standard with time, as it will certainly unlock a whole new set of possibilities for NFT-related projects. While they were developed before the finalization of this standard, Decentraland and ENS already implement the same pattern in their own contracts, so these collections are already compatible with Decentralease.

## What's next for Decentralease

While digital-native web3 gaming assets are a perfect beachhead for the protocol, I see immense potential for more creative applications of ERC-4907. Some that come to mind are:

1. Free trials for web3 games issued by game developers
2. Subscription services like Spotify and Netflix, where the creator is the **owner** and users must pay them directly
3. Buy-now-pay-later with automatic reclamation
4. Financial instruments for real-world assets represented on-chain (i.e. a house represented by an NFT with a mortgage)

My next step is to build #1, which will entail creating an interface for game developers to list their assets for free and require statements in the method for handling free trial claims to ensure that a particular address can only claim on a free trial.

Additionally, I plan to build a user-friendly interface for migrating an ERC-721 contract to ERC-4907 with a factory. The success of Decentralease will require widespread adoption of ERC-4907.
