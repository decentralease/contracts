// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./WrapDoNFT.sol";
import "./IComplexDoNFT.sol";
import "./dualRoles/IERC4907.sol";
import "./dualRoles/wrap/IWrapNFT.sol";
import "./royalty/Royalty.sol";
import "@thirdweb-dev/contracts/feature/ContractMetadata.sol";
import "hardhat/console.sol";

contract ComplexDoNFT is WrapDoNFT, Royalty, IComplexDoNFT, ContractMetadata {
    using EnumerableSet for EnumerableSet.UintSet;

    function initialize(
        string memory name_,
        string memory symbol_,
        address nftAddress_,
        address market_,
        address owner_,
        address admin_,
        address royaltyAdmin_
    ) override public virtual initializer {
        super._BaseDoNFT_init(
            name_,
            symbol_,
            nftAddress_,
            market_,
            owner_,
            admin_
        );
        royaltyAdmin = royaltyAdmin_;
    }

    function mintVNft(uint256 oid)
        public
        virtual
        override
        nonReentrant
        returns (uint256 tid)
    {
        require(oid2vid[oid] == 0, "already warped");
        address lastOwner;

        if (
            IERC165(oNftAddress).supportsInterface(type(IWrapNFT).interfaceId)
        ) {
            address gameNFTAddress = IWrapNFT(oNftAddress).originalAddress();
            lastOwner = ERC721(gameNFTAddress).ownerOf(oid);
            if (lastOwner != oNftAddress) {
                require(
                    onlyApprovedOrOwner(msg.sender, gameNFTAddress, oid),
                    "only approved or owner"
                );
                ERC721(gameNFTAddress).safeTransferFrom(
                    lastOwner,
                    address(this),
                    oid
                );
                ERC721(gameNFTAddress).approve(oNftAddress, oid);
                oid = IWrapNFT(oNftAddress).stake(oid);
            } else {
                require(
                    onlyApprovedOrOwner(msg.sender, oNftAddress, oid),
                    "only approved or owner"
                );
                lastOwner = ERC721(oNftAddress).ownerOf(oid);
                ERC721(oNftAddress).safeTransferFrom(
                    lastOwner,
                    address(this),
                    oid
                );
            }
        } else {
            require(
                onlyApprovedOrOwner(msg.sender, oNftAddress, oid),
                "only approved or owner"
            );
            lastOwner = ERC721(oNftAddress).ownerOf(oid);
            ERC721(oNftAddress).safeTransferFrom(lastOwner, address(this), oid);
        }

        tid = mintDoNft(
            lastOwner,
            oid,
            uint64(block.timestamp),
            type(uint64).max
        );
        oid2vid[oid] = tid;
        IERC4907(oNftAddress).setUser(oid, lastOwner, type(uint64).max);
    }

    function checkIn(
        address to,
        uint256 tokenId,
        uint256 durationId
    ) public virtual override(BaseDoNFT, IBaseDoNFT) {
        BaseDoNFT.checkIn(to, tokenId, durationId);
        IERC4907(oNftAddress).setUser(
            doNftMapping[tokenId].oid,
            to,
            durationMapping[durationId].end
        );
    }

    function getUser(uint256 originalNftId)
        public
        view
        virtual
        override
        returns (address)
    {
        return IERC4907(oNftAddress).userOf(originalNftId);
    }

    function redeem(uint256 tokenId, uint256[] calldata durationIds)
        public
        virtual
        override
    {
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            "ERC721: transfer caller is not owner nor approved"
        );
        require(couldRedeem(tokenId, durationIds), "cannot redeem");
        DoNftInfo storage info = doNftMapping[tokenId];

        if (
            IERC165(oNftAddress).supportsInterface(type(IWrapNFT).interfaceId)
        ) {
            IWrapNFT(oNftAddress).redeem(info.oid);
            address gameNFTAddress = IWrapNFT(oNftAddress).originalAddress();
            ERC721(gameNFTAddress).safeTransferFrom(
                address(this),
                ownerOf(tokenId),
                info.oid
            );
        } else {
            ERC721(oNftAddress).safeTransferFrom(
                address(this),
                ownerOf(tokenId),
                info.oid
            );
        }

        _burnVNft(tokenId);
        emit Redeem(info.oid, tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override
        returns (bool)
    {
        return
            interfaceId == type(IComplexDoNFT).interfaceId ||
            interfaceId == type(IRoyalty).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );
        return IERC721Metadata(oNftAddress).tokenURI(this.getOriginalNftId(tokenId));
    }

    function _canSetContractURI() internal view override returns (bool) {
        // example implementation:
        return msg.sender == owner;
    }
}
