// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract CPAMM {
    // Tokens in the contract
    IERC20 public immutable token0;
    IERC20 public immutable token1;

    // amount of reserve
    uint256 public reserve0;
    uint256 public reserve1;

    // Shares
    uint256 public totalSupply;
    // Track balances
    mapping(address => uint256) public balanceOf;

    constructor(address _token0, address _token1) payable {
        token0 = IERC20(_token0);
        token1 = IERC20(_token1);
    }

    /** */
    function _mint(address _to, uint256 _amount) private {
        balanceOf[_to] += _amount;
        totalSupply += _amount;
    }

    /** */
    function _burn(address _from, uint256 _amount) private {
        balanceOf[_from] -= _amount;
        totalSupply -= _amount;
    }

    // this is implemeted to prevent users from sending tokens directly
    // to the contract to messup the shares to be minted
    function _update(uint _reserve0, uint _reserve1) private {
        reserve0 = _reserve0;
        reserve1 = _reserve1;
    }

    function _sqrt(uint y) private pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    function _min(uint x, uint y) private pure returns (uint) {
        return x <= y ? x : y;
    }

    function swap(
        address _tokenIn,
        uint256 _amountIn
    ) external returns (uint256 amountOut) {
        require(
            _tokenIn == address(token0) || _tokenIn == address(token1),
            "Invalid Token"
        );
        require(_amountIn > 0, "amount in = 0");

        // Pull in token in
        bool isToken0 = _tokenIn == address(token0);
        (
            IERC20 tokenIn,
            IERC20 tokenOut,
            uint reserveIn,
            uint reserveOut
        ) = isToken0
                ? (token0, token1, reserve0, reserve1)
                : (token1, token0, reserve1, reserve0);
        tokenIn.transferFrom(msg.sender, address(this), _amountIn);
        // Calculate token out (include fees), fee 0.3%
        // ydx / (x + dx) = dy
        // y = reserveOut
        // dx = amountInWithFee
        // x = reserveIn
        // dy = amountOut
        uint amountInWithFee = (_amountIn * 997) / 1000;
        amountOut =
            (reserveOut * amountInWithFee) /
            (reserveIn + amountInWithFee);
        // Transfer token out to msg.msg.sender
        tokenOut.transfer(msg.sender, amountOut);
        // Update reserves
        _update(
            token0.balanceOf(address(this)),
            token1.balanceOf(address(this))
        );
    }

    function addLiquidity(
        uint _amount0,
        uint _amount1
    ) external returns (uint shares) {
        // Pull in token0 and token1
        token0.transferFrom(msg.sender, address(this), _amount0);
        token1.transferFrom(msg.sender, address(this), _amount1);

        // dy / dx = y / x
        if (reserve0 > 0 || reserve1 > 0) {
            require(
                reserve0 * _amount1 == reserve1 * _amount0,
                "dy / dx != y /x"
            );
        }
        // Mint shares
        // f(x, y) = value of liquidity = sqrt(xy)
        // s = dx / x * T = dy / y * T
        // y = reserve1
        // dx = _amount0
        // x = reserve0
        // dy = _amount1
        // T = totalSupply
        if (totalSupply == 0) {
            shares = _sqrt(_amount0 * _amount1);
        } else {
            shares = _min(
                (_amount0 * totalSupply) / reserve0,
                (_amount1 * totalSupply) / reserve1
            );
        }
        require(shares > 0, "shares = 0");
        _mint(msg.sender, shares);

        // Update reserves
        _update(
            token0.balanceOf(address(this)),
            token1.balanceOf(address(this))
        );
    }

    function removeLiquidity(
        uint _shares
    ) external returns (uint amount0, uint amount1) {
        // Calculate amount0 and amount1 to withdraw
        // dy = s /T * x
        // dx = s / T * y
        // x = reserve0
        // y = reserve1
        // dy = _amount1
        // dx = _amount0
        // T = totalSupply
        uint bal0 = token0.balanceOf(address(this));
        uint bal1 = token1.balanceOf(address(this));

        amount0 = (_shares * bal0) / totalSupply;
        amount1 = (_shares * bal1) / totalSupply;

        // Burn shares
        _burn(msg.sender, _shares);
        // Update reserves
        _update(
            bal0 - amount0,
            bal1 - amount1
        );
        // Transfer tokens to msg.sender
        token0.transfer(msg.sender, amount0);
        token1.transfer(msg.sender, amount1);
    }
}
