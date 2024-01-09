// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interface/ICompliantToken.sol";

contract CrowdSale is Pausable, Ownable {
    using SafeERC20 for IERC20;
    using SafeERC20 for ICompliantToken;

    // -----------------------------------------
    // STATE VARIABLES
    // -----------------------------------------

    // Token being sold
    ICompliantToken public token;

    // Drex token address
    IERC20 public drex;

    // Address where funds are collected
    address public fundingWallet;

    // Amount of drex raised
    uint256 public amoutRaised;

    // Timestamp when token started to sell
    uint256 public openTime;

    // Timestamp when token stopped to sell
    uint256 public closeTime;

    // Timestamp when starts the claim distribution period
    uint256 public releaseTime;

    // Timestamp when ends the claim distribution period
    uint256 public releaseEndTime;

    // Amount of tokens sold
    uint256 public tokenSold;

    // Amount of tokens claimed
    uint256 public tokenClaimed;

    // Amount of tokens to sold out
    uint256 public saleAmountToken;

    // Amount of token to be raised in drex (1e6)
    uint256 public saleAmountDrex;

    // Minimum amount of token to be sold for claim to be possible. Otherwise, refund will happen
    uint256 public minimumSaleAmountForClaim;

    bool public isLoaded;

    // Max amout of drex allowed to buy
    uint256 public maxBuyAllowed = 20000 * 1e6;

    // 3% in bp
    uint256 platformFee = 300;

    // User struct to store user operations
    struct UserControl {
        uint256 tokensBought;
        uint256 tokensClaimed;
        uint256 drexSpent;
    }

    // Token sold mapping to delivery
    mapping(address => UserControl) private userTokensMapping;

    // -----------------------------------------
    // EVENTS
    // -----------------------------------------

    event SaleCreated(
        address saleAddress,
        address token,
        uint256 openTime,
        uint256 closeTime,
        uint256 releaseTime,
        uint256 releaseEndTime,
        uint256 drexConversionRate,
        uint256 saleAmount,
        uint256 minimumSaleAmountForClaim
    );
    event TokenPurchase(address indexed purchaser, uint256 drexAmount);
    event SaleLoaded(uint256 amount);
    event RefundRemainingTokensToOwner(address owner, uint256 amount);
    event TokenClaimed(address wallet, uint256 amount);
    event DrexConversionRateChanged(uint256 rate);
    event FundingWalletChanged(address wallet);
    event MinimumSaleAmountForClaimChanged(uint256 amount);
    event ScheduleChanged(
        uint256 openTime,
        uint256 closeTime,
        uint256 releaseTime
    );
    event RefundUser(address wallet, uint256 drexAmount);
    event SendAmountRaisedToFundingWallet(
        address wallet,
        uint256 drexAmount,
        address owner,
        uint256 feeAmount
    );

    // -----------------------------------------
    // CONSTRUCTOR
    // -----------------------------------------
    /**
     * @param _token address of ERC20 token being sold.
     * @param _drex address of Drex token.
     * @param _duration Number of Sale duration time.
     * @param _openTime Timestamp of when Sale starts.
     * @param _releaseTime Timestamp of when Slae claim period starts.
     * @param _saleAmountDrex Amount of token to be raised in Drex (1e6).
     * @param _saleAmountToken Amount of token to be raised in token (1eDecimals).
     * @param _minimumSaleAmountForClaim Minimum amount of token to be sold for claim to be possible.
     * @param _fundingWallet Address where collected funds will be forwarded to.
     */
    constructor(
        ICompliantToken _token,
        IERC20 _drex,
        uint256 _duration,
        uint256 _openTime,
        uint256 _releaseTime,
        uint256 _releaseDuration,
        uint256 _saleAmountDrex,
        uint256 _saleAmountToken,
        uint256 _minimumSaleAmountForClaim,
        address _fundingWallet
    ) Ownable(_msgSender()) {
        require(address(_token) != address(0), "CrowdSale::ZERO_ADDRESS");
        require(address(_drex) != address(0), "CrowdSale::ZERO_ADDRESS");
        require(_duration != 0, "CrowdSale::ZERO_DURATION");
        require(_releaseDuration != 0, "CrowdSale::ZERO_RELEASE_DURATION");
        require(_openTime >= block.timestamp, "CrowdSale::INVALID_OPEN_TIME");
        require(_saleAmountDrex > 0, "CrowdSale::INVALID_RAISE_AMOUNT");
        require(
            minimumSaleAmountForClaim >= 0 &&
                minimumSaleAmountForClaim <= _saleAmountToken,
            "CrowdSale::INVALID_MINIMUM_SALE_AMOUNT"
        );
        require(
            _openTime + _duration <= _releaseTime,
            "CrowdSale::INVALID_RELEASE_START_TIME"
        );
        require(_saleAmountToken > 0, "CrowdSale::INVALID_RAISE_AMOUNT_TOKEN");
        require(_fundingWallet != address(0), "CrowdSale::ZERO_ADDRESS");

        token = _token;
        drex = _drex;
        openTime = _openTime;
        closeTime = _openTime + _duration;
        releaseTime = _releaseTime;
        releaseEndTime = _releaseTime + _releaseDuration;
        saleAmountDrex = _saleAmountDrex;
        saleAmountToken = _saleAmountToken;
        minimumSaleAmountForClaim = _minimumSaleAmountForClaim;
        fundingWallet = _fundingWallet;

        emit SaleCreated(
            address(this),
            address(token),
            openTime,
            closeTime,
            releaseTime,
            releaseEndTime,
            saleAmountDrex,
            saleAmountToken,
            minimumSaleAmountForClaim
        );
    }

    // -----------------------------------------
    // VIEWS
    // -----------------------------------------

    /**
     * @notice Returns the Buyable tokens of an address
     * @return buyableTokens Returns amount of tokens the user can buy
     * @param _address Address to find the amount of tokens
     */
    function getBuyableTokens(
        address _address
    ) public view returns (uint256 buyableTokens) {
        buyableTokens =
            calculateTokenAmount(maxBuyAllowed) -
            userTokensMapping[_address].tokensBought;
    }

    /**
     * @notice calculate the conversion rate of the token
     * @return tokenAmount Returns the amount of tokens
     * @param drexAmount Amount of Drex to calculate
     */
    function calculateTokenAmount(
        uint256 drexAmount
    ) public view returns (uint256 tokenAmount) {
        tokenAmount = (drexAmount * saleAmountToken) / saleAmountDrex;
    }

    /**
     * @notice Returns the available tokens of Sale
     * @return availableTokens Returns amount of tokens available to buy in the Sale
     */
    function getAvailableTokens()
        public
        view
        returns (uint256 availableTokens)
    {
        availableTokens = saleAmountToken - tokenSold;
    }

    /**
     * @notice Returns the Total Claimable tokens of an address
     * @return claimableTokens Returns amount of tokens the user can calaim
     * @param _address Address to find the amount of tokens
     */
    function getClaimableTokens(
        address _address
    ) external view returns (uint256 claimableTokens) {
        UserControl storage user = userTokensMapping[_address];
        claimableTokens = user.tokensBought - user.tokensClaimed;
    }

    /**
     * @notice Returns the Bought tokens of an address
     * @return boughtTokens Returns amount of tokens the user bought
     * @param _address Address to find the amount of tokens
     */
    function getBoughtTokens(
        address _address
    ) external view returns (uint256 boughtTokens) {
        boughtTokens = userTokensMapping[_address].tokensBought;
    }

    /**
     * @notice Returns the Drex amount available for refund
     * @return drexAmount Returns amount of Drex tokens user has available for refund
     * @param _address User address to find the amount of tokens
     */
    function getDrexAvailableForRefund(
        address _address
    ) external view returns (uint256 drexAmount) {
        if (!isOverAndDidnSellEnought()) {
            drexAmount = userTokensMapping[_address].drexSpent;
        } else {
            drexAmount = 0;
        }
    }

    /**
     * @notice Returns the Available tokens to claim of an address
     * @return availableTokens Returns amount of tokens the user can calain at this moment
     * @param _address Address to find the amount of tokens
     */
    function getAvailableTokensToClaim(
        address _address
    ) public view returns (uint256 availableTokens) {
        if (!isClaimable()) {
            availableTokens = 0;
        } else {
            UserControl storage userInfo = userTokensMapping[_address];

            uint256 lastTimeReleaseApplicable = block.timestamp < releaseEndTime
                ? block.timestamp
                : releaseEndTime;

            uint256 timeElapsed = lastTimeReleaseApplicable - releaseTime;

            availableTokens =
                (((userInfo.tokensBought * 10) / 100) +
                    ((90 * userInfo.tokensBought * timeElapsed) /
                        100 /
                        (releaseEndTime - releaseTime))) -
                userInfo.tokensClaimed;
        }
    }

    /**
     * @notice Return true if sale has sold enough tokens for refund not to happen
     * @dev Funding Wallet will only receive funds from sale if sale has sold enough tokens
     * @return soldEnough true if tokenSold >= minimumSaleAmountForClaim.
     */
    function soldEnoughForClaim() public view returns (bool soldEnough) {
        soldEnough = tokenSold >= minimumSaleAmountForClaim;
    }

    /**
     * @notice Return true if sale has ended and is eneable to claim
     * @dev User cannot claim tokens when isClaimable == false
     * @return claimable true if the release time < now.
     */
    function isClaimable() public view returns (bool claimable) {
        claimable =
            block.timestamp >= releaseTime &&
            isLoaded &&
            soldEnoughForClaim();
    }

    /**
     * @notice Return true if sale has ended and didnt meet minimum sale amount
     * @dev everyone gets refunds if this happens
     * @return needsRefund true if the release time < now and tokensSold < minimumSaleAmountForClaim
     */
    function isOverAndDidnSellEnought() public view returns (bool needsRefund) {
        needsRefund =
            block.timestamp >= releaseTime &&
            isLoaded &&
            !soldEnoughForClaim();
    }

    /**
     * @notice Return true if sale is open
     * @dev User can purchase / trade tokens when isOpen == true
     * @return open true if the Sale is open.
     */
    function isOpen() public view returns (bool open) {
        open =
            (block.timestamp <= closeTime) &&
            (block.timestamp >= openTime) &&
            isLoaded;
    }

    // -----------------------------------------
    // MUTATIVE FUNCTIONS
    // -----------------------------------------

    /**
     * @notice User can buy token by this function when available.
     * @dev low level token purchase ***DO NOT OVERRIDE***
     */
    function buyToken(uint256 _amount) public whenNotPaused {
        require(!paused(), "CrowdSale::PAUSED");
        require(_amount > 1e6, "CrowdSale::INVALID_AMOUNT");
        require(isLoaded, "CrowdSale::NOT_LOADED");
        require(isOpen(), "CrowdSale::PURCHASE_NOT_ALLOWED");

        // calculate token amount to be sold
        uint256 _tokenAmount = calculateTokenAmount(_amount);

        require(
            _tokenAmount <= getBuyableTokens(_msgSender()),
            "CrowdSale::MAX_BUY_AMOUNT_EXEDED"
        );
        require(
            getAvailableTokens() >= _tokenAmount,
            "CrowdSale::NOT_ENOUGH_AVAILABLE_TOKENS"
        );

        require(token.isWhitelisted(_msgSender()), "Token::NOT_WHITELISTED");

        drex.safeTransferFrom(_msgSender(), address(this), _amount);

        tokenSold += _tokenAmount;
        userTokensMapping[_msgSender()].tokensBought += _tokenAmount;

        amoutRaised += _amount;

        userTokensMapping[_msgSender()].drexSpent += _amount;

        emit TokenPurchase(_msgSender(), _amount);
    }

    function claimTokens() public whenNotPaused {
        require(!paused(), "CrowdSale::PAUSED");
        require(isClaimable(), "CrowdSale::SALE_NOT_ENDED");
        uint256 _tokenAmount = getAvailableTokensToClaim(_msgSender());
        require(_tokenAmount > 0, "CrowdSale::EMPTY_BALANCE");

        token.safeTransfer(_msgSender(), _tokenAmount);

        tokenClaimed += _tokenAmount;
        userTokensMapping[_msgSender()].tokensClaimed += _tokenAmount;

        emit TokenClaimed(_msgSender(), _tokenAmount);
    }

    /**
     * @notice Check the amount of tokens is bigger than saleAmount and enable to buy
     */
    function loadSale() external onlyOwner {
        require(!isLoaded, "CrowdSale::LOAD_ALREADY_VERIFIED");
        require(block.timestamp < openTime, "CrowdSale::SALE_ALREADY_STARTED");
        require(
            token.balanceOf(_msgSender()) >= saleAmountToken &&
                token.allowance(_msgSender(), address(this)) >= saleAmountToken,
            "CrowdSale::NOT_ENOUGH_TOKENS"
        );

        token.safeTransferFrom(_msgSender(), address(this), saleAmountToken);
        isLoaded = true;
        emit SaleLoaded(saleAmountToken);
    }

    /**
     * @notice Owner can receive their remaining tokens when sale Ended
     * @dev  Can refund remaining token if the sale ended
     * @param _wallet Address wallet who receive the remainning tokens when sale end
     */
    function refundRemainingTokensToOwner(address _wallet) external onlyOwner {
        require(isClaimable(), "CrowdSale::SALE_NOT_ENDED");
        uint256 remainingTokens = getAvailableTokens();
        require(remainingTokens > 0, "CrowdSale::EMPTY_BALANCE");
        token.safeTransfer(_wallet, remainingTokens);
        emit RefundRemainingTokensToOwner(_wallet, remainingTokens);
    }

    /**
     * @notice Owner can receive all tokens when sale ended and didnt meet threshold
     * @dev  Can refund all tokens if the sale ended
     * @param _wallet Address wallet who receives all tokens when sale end and didnt meet threshold
     */
    function refundAllTokensToOwner(address _wallet) external onlyOwner {
        require(
            isOverAndDidnSellEnought(),
            "CrowdSale::NOT_QUALIFIED_FOR_FULL_REFUND"
        );
        token.safeTransfer(_wallet, saleAmountToken);
        emit RefundRemainingTokensToOwner(_wallet, saleAmountToken);
    }

    //  Users can receive refund if sale Ended and Threshold is NOT met
    function refundUser() public {
        require(
            isOverAndDidnSellEnought(),
            "CrowdSale::NOT_QUALIFIED_FOR_FULL_REFUND"
        );

        uint256 drexAmount = userTokensMapping[_msgSender()].drexSpent;

        require(drexAmount > 0, "CrowdSale::EMPTY_BALANCE");

        drex.safeTransfer(_msgSender(), drexAmount);
        userTokensMapping[_msgSender()].drexSpent = 0;

        emit RefundUser(_msgSender(), drexAmount);
    }

    /**
     * @notice FundingWallet can receive the tokens raised if sale Ended and Threshold is met
     */
    function sendAmoutRaisedToFundingWallet() external onlyOwner {
        require(isClaimable(), "CrowdSale::SALE_NOT_ENDED");

        uint256 drexAmount = amoutRaised;

        uint256 feeAmount = (amoutRaised * platformFee) / 1e5;

        token.safeTransfer(fundingWallet, amoutRaised - feeAmount);
        token.safeTransfer(owner(), feeAmount);
        emit SendAmountRaisedToFundingWallet(
            fundingWallet,
            drexAmount,
            owner(),
            feeAmount
        );
    }

    /**
     * @notice Owner can set the conversion rate.
     * @param _newAmount New amount of drex to be raised
     */
    function setSaleAmountDrex(uint256 _newAmount) external onlyOwner {
        require(saleAmountDrex != _newAmount, "CrowdSale::RATE_INVALID");
        require(!isClaimable(), "CrowdSale::SALE_ENDED");

        saleAmountDrex = _newAmount;
        emit DrexConversionRateChanged(_newAmount);
    }

    /**
     * @notice Owner can set the fundingWallet where funds are collected
     * @param _address Address of funding wallets. Sold tokens in drex will transfer to this address
     */
    function setFundingWallet(address _address) external onlyOwner {
        require(_address != address(0), "CrowdSale::ZERO_ADDRESS");
        require(!isClaimable(), "CrowdSale::SALE_ENDED");
        require(
            fundingWallet != _address,
            "CrowdSale::FUNDING_WALLET_INVALID"
        );
        fundingWallet = _address;
        emit FundingWalletChanged(_address);
    }

    /**
     * @notice Owner can set the a new threshold for claiming to be possible
     * @param _amount new token amount that need to be sold for claiming to be possible
     */
    function setMinimumSaleAmountForClaim(uint256 _amount) external onlyOwner {
        require(
            _amount > 0 && _amount <= saleAmountToken,
            "CrowdSale::MINIMUM_AMOUNT_INVALID"
        );
        minimumSaleAmountForClaim = _amount;
        emit MinimumSaleAmountForClaimChanged(_amount);
    }

    /**
     * @notice Owner can set the close time (time in seconds). User can buy before close time.
     * @param _openTime Value in uint256 determine when we allow user to buy tokens.
     * @param _duration Value in uint256 determine the duration of user can buy tokens.
     * @param _releaseTime Value in uint256 determine when starts the claim period.
     */
    function setSchedule(
        uint256 _openTime,
        uint256 _duration,
        uint256 _releaseTime,
        uint256 _releaseDuration
    ) external onlyOwner {
        require(_openTime >= block.timestamp, "CrowdSale::INVALID_OPEN_TIME");
        require(
            _openTime + _duration <= _releaseTime,
            "CrowdSale::INVALID_RELEASE_TIME"
        );
        require(!isClaimable(), "CrowdSale::SALE_ENDED");

        openTime = _openTime;
        closeTime = _openTime + _duration;
        releaseTime = _releaseTime;
        releaseEndTime = _releaseTime + _releaseDuration;
        emit ScheduleChanged(_openTime, _duration, _releaseTime);
    }

    /**
     * @dev Called by the owner to pause, triggers stopped state
     */
    function pause() public onlyOwner {
        _pause();
    }

    /**
     * @dev Called by the owner to unpause, returns to normal state
     */
    function unpause() public onlyOwner {
        _unpause();
    }
}
