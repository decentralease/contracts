// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "./IMarket.sol";
import "../OwnableContract.sol";
import "../IComplexDoNFT.sol";
import "../dualRoles/wrap/IWrapNFT.sol";

contract Market is OwnableContract, ReentrancyGuardUpgradeable, IMarket {
    uint64 private constant E5 = 1e5;
    mapping(address => mapping(uint256 => Lending)) internal lendingMap;
    mapping(address => mapping(uint256 => PaymentNormal))
    internal paymentNormalMap;

    struct SigmaInfo {
        uint256 pricePerDay;
        uint256 minDuration;
    }

    struct PaymentSigma {
        address token;
        SigmaInfo[] infos;
    }

    mapping(address => mapping(uint256 => PaymentSigma)) internal paymentSigmaMap;
    mapping(address => mapping(address => uint256)) internal royaltyMap;
    mapping(address => uint256) public balanceOfFee;
    address payable public beneficiary;
    uint256 private fee;
    uint64 public maxIndate;
    bool public isPausing;
    bool public supportERC20;

    function initialize(address owner_, address admin_) public initializer {
        __ReentrancyGuard_init();
        initOwnableContract(owner_, admin_);
        maxIndate = 365 days;
        fee = 2500;
    }

    function onlyApprovedOrOwner(
        address spender,
        address nftAddress,
        uint256 nftId
    ) internal view {
        address _owner = ERC721(nftAddress).ownerOf(nftId);
        require(
            spender == _owner ||
            ERC721(nftAddress).getApproved(nftId) == spender ||
            ERC721(nftAddress).isApprovedForAll(_owner, spender),
            "only approved or owner"
        );
    }

    modifier whenNotPaused() {
        require(!isPausing, "is pausing");
        _;
    }

    function mintAndCreateLendOrder(
        address doNftAddress,
        uint256 oNftId,
        uint64 maxEndTime,
        uint64 minDuration,
        uint256 pricePerDay,
        address paymentToken
    ) override public nonReentrant {
        uint256 nftId = _mintV(doNftAddress, oNftId, maxEndTime);
        createLendOrder(
            doNftAddress,
            nftId,
            maxEndTime,
            minDuration,
            pricePerDay,
            paymentToken
        );
    }

    function mintAndCreatePrivateLendOrder(
        address doNftAddress,
        uint256 oNftId,
        uint64 maxEndTime,
        uint64 minDuration,
        uint256 pricePerDay,
        address paymentToken,
        address renter,
        OrderType orderType
    ) public nonReentrant {
        uint256 nftId = _mintV(doNftAddress, oNftId, maxEndTime);
        createPrivateLendOrder(
            doNftAddress,
            nftId,
            maxEndTime,
            minDuration,
            pricePerDay,
            paymentToken,
            renter,
            orderType
        );
    }

    function _mintV(
        address doNftAddress,
        uint256 oNftId,
        uint64 maxEndTime
    ) internal returns (uint256 nftId) {
        address oNftAddress = IComplexDoNFT(doNftAddress)
        .getOriginalNftAddress();
        if (
            IERC165(oNftAddress).supportsInterface(type(IWrapNFT).interfaceId)
        ) {
            address gameNFTAddress = IWrapNFT(oNftAddress).originalAddress();
            bool isStaked = ERC721(gameNFTAddress).ownerOf(oNftId) ==
            oNftAddress;
            if (isStaked) {
                onlyApprovedOrOwner(msg.sender, oNftAddress, oNftId);
            } else {
                onlyApprovedOrOwner(msg.sender, gameNFTAddress, oNftId);
            }
        } else {
            onlyApprovedOrOwner(msg.sender, oNftAddress, oNftId);
        }
        require(maxEndTime > block.timestamp, "invalid maxEndTime");
        nftId = IComplexDoNFT(doNftAddress).mintVNft(oNftId);
    }

    function createLendOrder(
        address nftAddress,
        uint256 nftId,
        uint64 maxEndTime,
        uint64 minDuration,
        uint256 pricePerDay,
        address paymentToken
    ) override public whenNotPaused {
        paymentNormalMap[nftAddress][nftId] = PaymentNormal(
            paymentToken,
            pricePerDay
        );
        _createLendOrder(
            nftAddress,
            nftId,
            maxEndTime,
            minDuration,
            pricePerDay,
            paymentToken,
            OrderType.Public,
            PaymentType.Normal,
            address(0)
        );
    }

    function createPrivateLendOrder(
        address nftAddress,
        uint256 nftId,
        uint64 maxEndTime,
        uint64 minDuration,
        uint256 pricePerDay,
        address paymentToken,
        address renter,
        OrderType orderType
    ) public whenNotPaused {
    }

    function isSorted(uint256[] memory l) private returns (bool) {
        if (l.length == 0) return true;
        for (uint256 i = 0; i < l.length - 1; i++) {
            if (l[i] > l[i + 1]) return false;
        }
        return true;
    }

    function mintAndCreateSigma(
        address nftAddress,
        uint256 nftId,
        address paymentToken,
        uint256[] memory prices,
        uint256[] memory durations,
        uint64 maxEndTime
    ) public {
        uint256 vnftId = _mintV(nftAddress, nftId, maxEndTime);
        createSigma(nftAddress, vnftId, paymentToken, prices, durations, maxEndTime);
    }

    function createSigma(
        address nftAddress,
        uint256 nftId,
        address paymentToken,
        uint256[] memory prices,
        uint256[] memory durations,
        uint64 maxEndTime
    ) public {
        onlyApprovedOrOwner(msg.sender, nftAddress, nftId);
        require(maxEndTime > block.timestamp, "invalid maxEndTime");
        require(durations.length == prices.length, "durations and prices differ in length");
        require(durations.length > 0, "there must be at least one duration");
        require(isSorted(durations), "durations must be sorted");
        (, , uint64 dEnd) = IComplexDoNFT(nftAddress).getDurationByIndex(
            nftId,
            0
        );
        if (maxEndTime > dEnd) {
            maxEndTime = dEnd;
        }
        if (maxEndTime > block.timestamp + maxIndate) {
            maxEndTime = uint64(block.timestamp) + maxIndate;
        }

        address _owner = ERC721(nftAddress).ownerOf(nftId);
        Lending storage lending = lendingMap[nftAddress][nftId];
        lending.lender = _owner;
        lending.nftAddress = nftAddress;
        lending.nftId = nftId;
        lending.maxEndTime = maxEndTime;
        lending.nonce = IComplexDoNFT(nftAddress).getNonce(nftId);
        lending.createTime = uint64(block.timestamp);
        lending.orderType = OrderType.Public;
        lending.paymentType = PaymentType.Normal;

        PaymentSigma storage ps = paymentSigmaMap[nftAddress][nftId];
        ps.token = paymentToken;
        for (uint256 i = 0; i < durations.length; i++) {
            ps.infos.push(SigmaInfo(prices[i], durations[i]));
        }
    }

    function _createLendOrder(
        address nftAddress,
        uint256 nftId,
        uint64 maxEndTime,
        uint64 minDuration,
        uint256 pricePerDay,
        address paymentToken,
        OrderType orderType,
        PaymentType paymentType,
        address renter
    ) internal {
        onlyApprovedOrOwner(msg.sender, nftAddress, nftId);
        require(maxEndTime > block.timestamp, "invalid maxEndTime");
        require(
            minDuration <= IComplexDoNFT(nftAddress).getMaxDuration(),
            "Error:minDuration > max"
        );
        require(
            IERC165(nftAddress).supportsInterface(
                type(IComplexDoNFT).interfaceId
            ),
            "not doNFT"
        );
        (, , uint64 dEnd) = IComplexDoNFT(nftAddress).getDurationByIndex(
            nftId,
            0
        );
        if (maxEndTime > dEnd) {
            maxEndTime = dEnd;
        }
        if (maxEndTime > block.timestamp + maxIndate) {
            maxEndTime = uint64(block.timestamp) + maxIndate;
        }

        address _owner = ERC721(nftAddress).ownerOf(nftId);
        Lending storage lending = lendingMap[nftAddress][nftId];
        lending.lender = _owner;
        lending.nftAddress = nftAddress;
        lending.nftId = nftId;
        lending.maxEndTime = maxEndTime;
        lending.minDuration = minDuration;
        lending.nonce = IComplexDoNFT(nftAddress).getNonce(nftId);
        lending.createTime = uint64(block.timestamp);
        lending.orderType = orderType;
        lending.paymentType = paymentType;

        emit CreateLendOrder(
            _owner,
            nftAddress,
            nftId,
            maxEndTime,
            minDuration,
            pricePerDay,
            paymentToken,
            renter,
            orderType
        );
    }

    function cancelLendOrder(address nftAddress, uint256 nftId)
    override
    public
    whenNotPaused
    {
        onlyApprovedOrOwner(msg.sender, nftAddress, nftId);
        delete lendingMap[nftAddress][nftId];
        delete paymentNormalMap[nftAddress][nftId];
        delete paymentSigmaMap[nftAddress][nftId];
        emit CancelLendOrder(msg.sender, nftAddress, nftId);
    }

    function getLendOrder(address nftAddress, uint256 nftId)
    override
    public
    view
    returns (Lending memory)
    {
        return lendingMap[nftAddress][nftId];
    }

    function getRenterOfPrivateLendOrder(address nftAddress, uint256 nftId)
    override
    external
    view
    returns (address)
    {
        return nftAddress;
    }

    function getPaymentNormal(address nftAddress, uint256 nftId)
    override
    external
    view
    returns (PaymentNormal memory)
    {
        return paymentNormalMap[nftAddress][nftId];
    }

    function getPaymentSigma(address nftAddress, uint256 nftId)
    external
    view
    returns (PaymentSigma memory)
    {
        PaymentSigma storage ps = paymentSigmaMap[nftAddress][nftId];
        return ps;
    }

    function fulfillOrderNow(
        address nftAddress,
        uint256 nftId,
        uint256 durationId,
        uint64 duration,
        address user
    ) override public payable virtual whenNotPaused nonReentrant returns (uint256 tid) {
        require(isLendOrderValid(nftAddress, nftId), "invalid order");
        Lending storage lending = lendingMap[nftAddress][nftId];
        require(lending.orderType == OrderType.Public, "only public orders");
        uint64 endTime = uint64(block.timestamp + duration - 1);
        if (endTime > lending.maxEndTime) {
            endTime = lending.maxEndTime;
        }
        (, uint64 dEnd) = IComplexDoNFT(nftAddress).getDuration(durationId);
        if (endTime > dEnd) {
            endTime = dEnd;
        }
        uint64 startTime = uint64(block.timestamp);
        distributePayment(nftAddress, nftId, startTime, endTime);
        tid = IComplexDoNFT(nftAddress).mint(
            nftId,
            durationId,
            startTime,
            endTime,
            msg.sender,
            user
        );
    }

    function distributePayment(
        address nftAddress,
        uint256 nftId,
        uint64 startTime,
        uint64 endTime
    )
    internal
    returns (
        uint256 totalPrice,
        uint256 leftTotalPrice,
        uint256 curFee,
        uint256 curRoyalty
    )
    {
        uint64 duration = endTime - startTime + 1;
        PaymentSigma storage ps = paymentSigmaMap[nftAddress][nftId];
        uint256 pricePerDay;
        for (uint256 i = ps.infos.length - 1; i >= 0; i--) {
            if (ps.infos[i].minDuration < duration) {
                pricePerDay = ps.infos[i].pricePerDay;
                break;
            }
        }
        totalPrice = (pricePerDay * (endTime - startTime + 1)) / 86400;
        curFee = (totalPrice * fee) / E5;
        curRoyalty =
        (totalPrice * IComplexDoNFT(nftAddress).getRoyaltyFee()) /
        E5;
        leftTotalPrice = totalPrice - curFee - curRoyalty;

        royaltyMap[nftAddress][ps.token] += curRoyalty;
        balanceOfFee[ps.token] += curFee;

        if (ps.token == address(0)) {
            require(msg.value >= totalPrice, "payment is not enough");
            Address.sendValue(
                payable(ERC721(nftAddress).ownerOf(nftId)),
                leftTotalPrice
            );
            if (msg.value > totalPrice) {
                Address.sendValue(payable(msg.sender), msg.value - totalPrice);
            }
        } else {
            uint256 balance_before = IERC20(ps.token).balanceOf(
                address(this)
            );
            SafeERC20.safeTransferFrom(
                IERC20(ps.token),
                msg.sender,
                address(this),
                totalPrice
            );
            uint256 balance_after = IERC20(ps.token).balanceOf(
                address(this)
            );
            require(
                balance_before + totalPrice == balance_after,
                "not support burn ERC20"
            );
            SafeERC20.safeTransfer(
                IERC20(ps.token),
                ERC721(nftAddress).ownerOf(nftId),
                leftTotalPrice
            );
        }
    }

    function setFee(uint256 fee_) override public onlyAdmin {
        require(fee_ <= 1e4, "invalid fee");
        fee = fee_;
    }

    function getFee() override public view returns (uint256) {
        return fee;
    }

    function setMarketBeneficiary(address payable beneficiary_)
    override
    public
    onlyOwner
    {
        beneficiary = beneficiary_;
    }

    function claimFee(address[] calldata paymentTokens)
    override
    public
    whenNotPaused
    nonReentrant
    {
        require(msg.sender == beneficiary, "not beneficiary");
        for (uint256 index = 0; index < paymentTokens.length; index++) {
            uint256 balance = balanceOfFee[paymentTokens[index]];
            if (balance > 0) {
                if (paymentTokens[index] == address(0)) {
                    Address.sendValue(beneficiary, balance);
                } else {
                    SafeERC20.safeTransfer(
                        IERC20(paymentTokens[index]),
                        beneficiary,
                        balance
                    );
                }
                balanceOfFee[paymentTokens[index]] = 0;
            }
        }
    }

    function balanceOfRoyalty(address nftAddress, address paymentToken)
    public
    view
    returns (uint256)
    {
        return royaltyMap[nftAddress][paymentToken];
    }

    function claimRoyalty(address nftAddress, address[] calldata paymentTokens)
    override
    public
    whenNotPaused
    nonReentrant
    {
        address payable _beneficiary = IComplexDoNFT(nftAddress)
        .getBeneficiary();
        require(msg.sender == _beneficiary, "not beneficiary");
        for (uint256 index = 0; index < paymentTokens.length; index++) {
            uint256 balance = royaltyMap[nftAddress][paymentTokens[index]];
            if (balance > 0) {
                if (paymentTokens[index] == address(0)) {
                    Address.sendValue(_beneficiary, balance);
                } else {
                    SafeERC20.safeTransfer(
                        IERC20(paymentTokens[index]),
                        _beneficiary,
                        balance
                    );
                }
                royaltyMap[nftAddress][paymentTokens[index]] = 0;
            }
        }
    }

    function isLendOrderValid(address nftAddress, uint256 nftId)
    override
    public
    view
    returns (bool)
    {
        Lending storage lending = lendingMap[nftAddress][nftId];
        if (isPausing) {
            return false;
        }
        return
        lending.nftId > 0 &&
        lending.maxEndTime > block.timestamp &&
        lending.nonce == IComplexDoNFT(nftAddress).getNonce(nftId);
    }

    function setPause(bool pause_) override public onlyAdmin {
        isPausing = pause_;
        if (isPausing) {
            emit Paused(address(this));
        } else {
            emit Unpaused(address(this));
        }
    }

    function setMaxIndate(uint64 max_) public onlyAdmin {
        maxIndate = max_;
    }

    function multicall(bytes[] calldata data)
    external
    returns (bytes[] memory results)
    {
        results = new bytes[](data.length);
        for (uint256 i = 0; i < data.length; i++) {
            (bool success, bytes memory result) = address(this).delegatecall(
                data[i]
            );
            if (success) {
                results[i] = result;
            }
        }
        return results;
    }
}
