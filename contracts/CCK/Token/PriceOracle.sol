// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

/**
 * @title PriceOracle
 * @dev A contract for retrieving the current price from a Uniswap V3 pool.
 */
contract PriceOracle {
    address public uniswapPool; // Address of the Uniswap V3 pool

    /**
     * @dev Constructor to set the Uniswap V3 pool address.
     * @param _uniswapPool Address of the Uniswap V3 pool to be used for price retrieval.
     */
    constructor(address _uniswapPool) {
        uniswapPool = _uniswapPool;
    }

    /**
     * @dev Retrieves the current price from the Uniswap V3 pool.
     * @return uint256 The current price calculated from the pool's sqrtPriceX96.
     */
    function getCurrentPrice() external view returns (uint256) {
        IUniswapV3Pool pool = IUniswapV3Pool(uniswapPool);
        (uint160 sqrtPriceX96, , , , , , ) = pool.slot0();
        uint256 price = uint256(sqrtPriceX96) ** 2 / (2 ** 192); // Price calculation
        return price;
    }
}