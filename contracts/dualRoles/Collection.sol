// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import "@thirdweb-dev/contracts/feature/interface/IMintableERC721.sol";
import "@thirdweb-dev/contracts/feature/ContractMetadata.sol";

import "./ERC4907.sol";
import "../OwnableContract.sol";

contract Collection is ERC4907, ERC721Enumerable, IMintableERC721, ContractMetadata, OwnableContract {

    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;

    mapping(uint256 => string) private _tokenURIs;

    constructor(
        address owner_,
        address admin_
    ) 
        ERC4907("Collection", "Collection") {
            initOwnableContract(owner_, admin_);
    }

    function mintTo(address to, string calldata uri) external override returns (uint256) {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
        _tokenURIs[tokenId] = uri;
        return tokenId;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        return _tokenURIs[tokenId];
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        override(ERC4907, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC4907, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function _canSetContractURI() internal view override returns (bool) {
        // example implementation:
        return msg.sender == owner;
    }
}
