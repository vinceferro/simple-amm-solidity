// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title SpaceCoinToken
 * @author TheV
 */
contract SpaceCoinToken is ERC20 {
    uint256 public constant INITIAL_SUPPLY = 500_000;
    uint256 public constant TRANSFER_TAX = 2;
    address public owner;
    address public treasuryAddress;
    bool public transferTaxEnabled = false;

    event TransferTaxToggled(bool enabled);

    /**
     * @notice Build the contract with the initial supply, set the contract owner and set the treasury address
     * @param _treasuryAddress The address of the treasury
     */
    constructor (address _treasuryAddress) ERC20("SpaceCoin", "SPC") {
        owner = msg.sender;
        treasuryAddress = _treasuryAddress;
        _mint(treasuryAddress, INITIAL_SUPPLY * (10 ** decimals()));
    }

    /**
     * @notice Allow the owner to toggle the transfer tax
     */
    function toggleTransferTax() external {
        require(msg.sender == owner, "E_OWNER_ONLY");
        transferTaxEnabled = !transferTaxEnabled;
        emit TransferTaxToggled(transferTaxEnabled);
    }

    /**
     * @notice applies the transfer tax to the transfered amount if enabled
     * @inheritdoc ERC20
     */
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        if (transferTaxEnabled && from != treasuryAddress && to != treasuryAddress) {
            uint256 tax = amount * TRANSFER_TAX / 100;
            super._transfer(from, treasuryAddress, tax);
            amount -= tax;
        }
        super._transfer(from, to, amount);
    }
}