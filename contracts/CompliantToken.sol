// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title Camada
 * @dev {ERC20} token, including:
 *
 *  - ability for holders to sign permits and save gas via one less tx on external token transfers through {ERC20Permit}
 *
 * The account that deploys the contract will specify main parameters via constructor,
 * paying close attention to "admin" address who will receive 100% of initial supply and
 * should then distribute tokens according to tokenomics & planning.
 * inherited from {ERC20} and {ERC20Permit}
 */

contract CompliantToken is ERC20Permit, Ownable, Pausable {
    mapping(address => bool) public whitelist;
    address crowdSale;

    /**
     * @dev Mints `initialSupply` amount of token and transfers them to `admin`.
     * Also sets domain separator under same token name for EIP712 in ERC20Permit.
     *
     * See {ERC20-constructor} and {ERC20Permit-constructor}.
     * @param initialSupply total supply of the token
     */
    constructor(
        uint256 initialSupply,
        string memory name,
        string memory symbol
    ) ERC20(name, symbol) ERC20Permit(name) Ownable(_msgSender()) {
        _mint(_msgSender(), initialSupply);
    }

    /**
     * @dev Mints `amount` of tokens to `account`. Can only be called by the contract owner.
     * @param account The address to receive the minted tokens.
     * @param amount The amount of tokens to mint.
     */
    function mint(address account, uint256 amount) public onlyOwner {
        _mint(account, amount);
    }

    /**
     * @dev Removes a single address from the whitelist. The function is internal and can only be used within the contract itself or inherited contracts.
     * @param _address The address to remove from the whitelist.
     */
    function removeFromWhitelist(address _address) internal {
        require(_address != address(0), "CompliantToken::INVALID_WALLET");

        whitelist[_address] = false;
    }

    /**
     * @dev Removes multiple addresses from the whitelist in a batch. Can only be called by the contract owner.
     * @param _addresses An array of addresses to remove from the whitelist.
     */
    function removeFromWhitelistBatch(
        address[] memory _addresses
    ) external onlyOwner {
        for (uint256 i = 0; i < _addresses.length; i++) {
            whitelist[_addresses[i]] = false;
        }
    }

     /**
     * @dev Adds a single address to the whitelist. The function is internal and can only be used within the contract itself or inherited contracts.
     * @param _address The address to add to the whitelist.
     */
    function addToWhitelist(address _address) internal {
        require(_address != address(0), "CompliantToken::INVALID_WALLET");

        whitelist[_address] = true;
    }

    /**
     * @dev Adds multiple addresses to the whitelist in a batch. Can only be called by the contract owner.
     * @param _addresses An array of addresses to add to the whitelist.
     */
    function addToWhitelistBatch(
        address[] memory _addresses
    ) external onlyOwner {
        for (uint256 i = 0; i < _addresses.length; i++) {
            whitelist[_addresses[i]] = true;
        }
    }

    function _update(
        address from,
        address to,
        uint256 /*value*/
    ) internal virtual override {
        // checks if `from` and `to` is whitelisted when transferring
        if (from != address(0) || to != address(0)) {
            require(whitelist[from], "CompliantToken::NOT_WHITELISTED");
            require(whitelist[to], "CompliantToken::NOT_WHITELISTED");
        }
        if (
            paused() &&
            (from != crowdSale || to != crowdSale || _msgSender() != owner())
        ) {
            require(paused(), "CompliantToken::NOT_ALLOWED_TO_TRANSFER");
        }
    }

    /**
     * @dev Executes the forceful transfer of `value` amount of tokens from `from` address to `to` address. Can only be called by the contract owner.
     * @param from Address from which tokens are to be transferred.
     * @param to Address to which tokens are to be transferred.
     * @param value The amount of tokens to transfer.
     * @return A boolean value indicating whether the operation succeeded.
     */
    function forceTransfer(
        address from,
        address to,
        uint256 value
    ) external onlyOwner returns (bool) {
        _transfer(from, to, value);
        return true;
    }

    /**
     * @dev Burns `value` amount of tokens from `account`, reducing the total supply. Can only be called by the contract owner.
     * @param account The address from which tokens will be burnt.
     * @param value The amount of tokens to burn.
     */
    function burn(address account, uint256 value) external onlyOwner {
        _burn(account,value);
    }

    /**
     * @dev Called by the owner to pause, triggers stopped state.
     */
    function pause() public onlyOwner {
        _pause();
    }

    /**
     * @dev Called by the owner to unpause, returns to normal state.
     */
    function unpause() public onlyOwner {
        _unpause();
    }

   /**
     * @dev Sets the CrowdSale contract address and adds it to the whitelist. This allows bypassing certain restrictions for the crowdsale contract. Can only be called by the contract owner.
     * @param _crowdSale The address of the crowdsale contract to be set.
     */
    function setCrowdSale(address _crowdSale) public onlyOwner {
        crowdSale = _crowdSale;
        whitelist[_crowdSale] = true;
    }

    /**
     * @dev Returns whether the specified address is whitelisted.
     * @param _address The address to check for whitelisting status.
     * @return The whitelisting status of the specified address.
     */
    function isWhitelisted(address _address) public view returns (bool) {
        return whitelist[_address];
    }
}
