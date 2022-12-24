// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "./Space.sol";

/**
 * @title SpaceLP
 * @author TheV
 */
contract SpaceLP is ERC20 {
    uint256 private rETH = 0;
    uint256 private rSPC = 0;

    IERC20 public immutable token;
    uint8 private locked = 1;

    uint256 public constant MINIMUM_LIQUIDITY = 10**3;

    event Mint(address indexed sender, uint256 eth, uint256 spc);
    event Burn(address indexed sender, uint256 amount0, uint256 amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint256 ethIn,
        uint256 spcIn,
        uint256 ethOut,
        uint256 spcOut,
        address indexed to
    );

    /**
     * @notice implements reentrancy guard lock
     * @dev uses 1 for free, 2 for looked to optimize gas usage
     */
    modifier lock() {
        require(locked == 1, "E_LOCKED");
        locked = 2;
        _;
        locked = 1;
    }

    /**
     * @notice Constructor for the SpaceLP contract.
     * @dev calls ERC20 base constructor with total supply = 0
     * @param spcAddress address of the SPC token contract
     */
    constructor(address spcAddress) ERC20("SpaceLP", "SPCLP") {
        token = IERC20(spcAddress);
    }

    /**
     * @notice gets the stored reserves of eth and spc
     * @return (uint256, uint256) ETH and SPC reserves
     */
    function getReserves() public view returns (uint256, uint256) {
        return (rETH, rSPC);
    }

    /**
     * @notice gets the balances from eth and spc
     * @dev queries the contract balance for ETH and balanceOf on SPC token
     * @return (uint256, uint256) ETH and SPC balances
     */
    function getBalances() public view returns (uint256, uint256) {
        return (address(this).balance, token.balanceOf(address(this)));
    }

    /**
     * @notice updates the reserves with the balances
     * @param _bETH uint256 ETH balance
     * @param _bSPC uint256 SPC balance
     */
    function _update(uint256 _bETH, uint256 _bSPC) internal {
        rETH = _bETH;
        rSPC = _bSPC;
    }

    /**
     * @notice mints tokens for liquidity providers
     * @param to the receiver of the tokens
     * @return (uint256) amount of minted LP tokens
     */
    function mint(address to) external lock returns (uint256) {
        (uint256 _rETH, uint256 _rSPC) = getReserves();
        (uint256 _bETH, uint256 _bSPC) = getBalances();
        uint256 ethIn = _bETH - _rETH;
        uint256 spcIn = _bSPC - _rSPC;

        uint256 liquidity = 0;
        uint256 totSupply = totalSupply();
        if (totSupply == 0) {
            liquidity = Space.sqrt(ethIn * spcIn) - MINIMUM_LIQUIDITY;
            _mint(address(1), MINIMUM_LIQUIDITY);
        } else {
            liquidity = Space.min((ethIn * totSupply) / _rETH, (spcIn * totSupply) / _rSPC);
        }
        require(liquidity > 0, "E_INSUFFICIENT_LIQUIDITY_MINTED");
        _mint(to, liquidity);
        _update(_bETH, _bSPC);
        emit Mint(msg.sender, ethIn, spcIn);
        return liquidity;
    }

    /**
     * @notice burns tokens and returns assets to the liquidity provider
     * @dev the amount to burn is assumed to be the contract balance, that
       is previously moved from the router contract
     * @param to the receiver of the assets
     */
    function burn(address to) external lock returns (uint256, uint256) {
        (uint256 _bETH, uint256 _bSPC) = getBalances();
        uint256 liquidity = balanceOf(address(this));

        uint256 _totalSupply = totalSupply();
        uint256 ethOut = (liquidity * _bETH) / _totalSupply;
        uint256 spcOut = (liquidity * _bSPC) / _totalSupply;
        require(ethOut > 0 && spcOut > 0, "E_INSUFFICIENT_LIQUIDITY_BURNED");
        _burn(address(this), liquidity);

        (bool success, ) = to.call{ value: ethOut }("");
        require(success, "E_BURN_FAILED_ETH");
        success = token.transfer(to, spcOut);
        require(success, "E_BURN_FAILED_SPC");

        (uint256 nextRETH, uint256 nextRSPC) = getBalances();
        _update(nextRETH, nextRSPC);

        emit Burn(msg.sender, ethOut, spcOut, to);
        return (ethOut, spcOut);
    }

    /**
     * @notice swaps the tokens
     * @dev this completes the swap initiated by the trader
       thru the router contract. Reverts on failed steps.
     * @param ethOut amount of eth to swap
     * @param spcOut amount of spc to swap
     * @param to the receiver of the assets
     */
    function swap(
        uint256 ethOut,
        uint256 spcOut,
        address to
    ) external lock {
        require(ethOut > 0 || spcOut > 0, "E_INVALID_OUTPUT_AMOUNT");
        require(to != address(token), "E_INVALID_TO");
        (uint256 _rETH, uint256 _rSPC) = getReserves(); // get current reserves
        require(ethOut < _rETH && spcOut < _rSPC, "E_INSUFFICIENT_LIQUIDITY");
        (uint256 _bETH, uint256 _bSPC) = getBalances(); // get current balances

        // calculate the amount of tokens sent in
        // the balance differes from the reserves due to the IN amount from the router
        // calculates delta between reserves and balances to determine inbound values
        uint256 ethIn = _bETH > _rETH - ethOut ? _bETH - (_rETH - ethOut) : 0;
        uint256 spcIn = _bSPC > _rSPC - spcOut ? _bSPC - (_rSPC - spcOut) : 0;
        require(ethIn > 0 || spcIn > 0, "E_INSUFFICIENT_INPUT_AMOUNT");

        // adjust constant product formula calculation considering the 1% fee
        uint256 ethAdjusted = _bETH * 100 - ethIn;
        uint256 spcAdjusted = _bSPC * 100 - spcIn;
        require((ethAdjusted * spcAdjusted) >= (_rETH * _rSPC * 100**2), "E_K_LOWERED");

        _update(_bETH - ethOut, _bSPC - spcOut); // update reserves

        if (ethOut > 0) {
            (bool success, ) = to.call{ value: ethOut }("");
            require(success, "E_SWAP_FAILED_ETH");
        }
        if (spcOut > 0) {
            bool success = token.transfer(to, spcOut);
            require(success, "E_SWAP_FAILED_SPC");
        }

        emit Swap(msg.sender, ethIn, spcIn, ethOut, spcIn, to);
    }

    receive() external payable {}
}
