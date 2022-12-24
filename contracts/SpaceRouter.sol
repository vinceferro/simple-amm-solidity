// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./SpaceLP.sol";
import "./SpaceCoinToken.sol";

/**
 * @title SpaceRouter
 * @author TheV
 */
contract SpaceRouter {
    SpaceLP public immutable pool;
    SpaceCoinToken public immutable token;

    event LiquidityAdded(address provider, uint256 eth, uint256 spc);
    event LiquidityWithdrawn(address provider, uint256 eth, uint256 spc);
    event Swap(address trader, uint256 ethIn, uint256 spcIn, uint256 ethOut, uint256 spcOut);

    uint8 private locked = 1;

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
     * @dev also initializes the Liquidity Pool!
     * @param spcAddress address of the SPC token contract
     */
    constructor(address spcAddress) {
        pool = new SpaceLP(spcAddress);
        token = SpaceCoinToken(spcAddress);
    }

    /**
     * @notice allow adding liquidity to the pool
     * @param _ethIn uint256 amount of ETH to add
     * @param _spcIn uint256 amount of SPC to add
     * @return (uint256) quantity of LP tokens minted for the liquidity provider
     */
    function addLiquidity(uint256 _ethIn, uint256 _spcIn) external payable lock returns (uint256) {
        require(0 < _ethIn && _ethIn <= msg.value, "E_INVALID_ETH_AMOUNT");
        require(0 < _spcIn, "E_INVALID_SPC_AMOUNT");
        require(token.allowance(msg.sender, address(this)) >= _spcIn, "E_INSUFFICIENT_SPC_ALLOWANCE");
        (bool success, bytes memory returndata) = address(pool).call{ value: _ethIn }("");
        verifyCallResult(success, returndata, "E_FAILED_ADD_LIQUIDITY_ETH");
        success = token.transferFrom(msg.sender, address(pool), _spcIn);
        require(success, "E_FAILED_ADD_LIQUIDITY_SPC");

        uint256 minted = pool.mint(msg.sender);
        emit LiquidityAdded(msg.sender, _ethIn, _spcIn);
        if (msg.value > _ethIn) {
            (success, ) = msg.sender.call{ value: msg.value - _ethIn }("");
            require(success, "E_FAILED_ADD_LIQUIDITY_ETH_REFUND");
        }
        return minted;
    }

    /**
     * @notice allow withdrawing liquidity from the pool
     * @param _burnAmount uint256 amount LP tokens to burn
     * @param _minETH uint256 minimum amount of ETH to withdraw
     * @param _minSPC uint256 minimum amount of SPC to withdraw
     * @return (uint256, uint256) actual amount of ETH and SPC withdrawn
     */
    function removeLiquidity(
        uint256 _burnAmount,
        uint256 _minETH,
        uint256 _minSPC
    ) external lock returns (uint256, uint256) {
        bool success = pool.transferFrom(msg.sender, address(pool), _burnAmount);
        require(success, "E_FAILED_REMOVE_LIQUIDITY");
        (uint256 ethOut, uint256 spcOut) = pool.burn(msg.sender);
        require(ethOut >= _minETH, "E_INSUFFICIENT_ETH");
        require(spcOut >= _minSPC, "E_INSUFFICIENT_SPC");
        emit LiquidityWithdrawn(msg.sender, ethOut, spcOut);
        return (ethOut, spcOut);
    }

    /**
     * @notice allow swapping ETH for SPC
     * @param _ethIn uint256 eth to swap in
     * @param _minSpcOut uint256 minimum amount of SPC to swap out
     * @return (uint256, uint256) actual amount of ETH and SPC swap out
     */
    function swapETHforSPC(uint256 _ethIn, uint256 _minSpcOut) external payable lock returns (uint256, uint256) {
        require(0 < _ethIn && _ethIn == msg.value, "E_INVALID_ETH_AMOUNT");
        return _swap(_ethIn, 0, 0, _minSpcOut);
    }

    /**
     * @notice allow swapping SPC for ETH
     * @param _spcIn uint256 spc to swap in
     * @param _minEthOut uint256 minimum amount of ETH to swap out
     * @return (uint256, uint256) actual amount of ETH and SPC swap out
     */
    function swapSPCforETH(uint256 _spcIn, uint256 _minEthOut) external lock returns (uint256, uint256) {
        require(0 < _spcIn && _spcIn <= token.allowance(msg.sender, address(this)), "E_INVALID_SPC_AMOUNT");
        return _swap(0, _spcIn, _minEthOut, 0);
    }

    /**
     * @notice internal swap function
     * @dev this function is used by swapETHforSPC and swapSPCforETH
     * @param _ethIn uint256 eth to swap in
     * @param _spcIn uint256 spc to swap in
     * @param _minEthOut uint256 minimum amount of ETH to swap out
     * @param _minSpcOut uint256 minimum amount of SPC to swap out
     */
    function _swap(
        uint256 _ethIn,
        uint256 _spcIn,
        uint256 _minEthOut,
        uint256 _minSpcOut
    ) private returns (uint256, uint256) {
        (uint256 rETH, uint256 rSPC) = pool.getReserves();
        uint256 _spcOut = getAmountOut(_ethIn, rETH, rSPC);
        uint256 _ethOut = getAmountOut(_spcIn, rSPC, rETH);
        require(_ethOut >= _minEthOut && _spcOut >= _minSpcOut, "E_INVALID_OUT_AMOUNTS");

        if (_spcIn > 0) {
            bool success = token.transferFrom(msg.sender, address(pool), _spcIn - (_spcIn / 100));
            require(success, "E_FAILED_SWAP_SPC");
        } else {
            (bool success, ) = address(pool).call{ value: _ethIn - (_ethIn / 100) }("");
            require(success, "E_FAILED_SWAP_ETH");
        }
        pool.swap(_ethOut, _spcOut, msg.sender);

        emit Swap(msg.sender, _ethIn, _spcIn, _ethOut, _spcOut);
        return (_ethOut, _spcOut);
    }

    /**
     * @notice calculates amount after fees
     * @dev replicates the formula ((amountIn - fee) * reserveOut) / (reserveIn * (amountIn - fee))
     * @param _amountIn value of the asset swapped in
     * @param _reserveIn reserve for the asset being swapped in
     * @param _reserveOut reserve for the asset being swapped out
     */
    function getAmountOut(
        uint256 _amountIn,
        uint256 _reserveIn,
        uint256 _reserveOut
    ) internal pure returns (uint256) {
        uint256 _amountInWFees = _amountIn * 99;
        uint256 _numerator = _amountInWFees * _reserveOut;
        uint256 _denominator = _reserveIn * 100 + _amountInWFees;
        return _numerator / _denominator;
    }

    /**
     * @dev Tool to verifies that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason using the provided one.
     */
    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            if (returndata.length > 0) {
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}
